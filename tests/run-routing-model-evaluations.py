#!/usr/bin/env python3
"""Run bounded, provider-neutral routing evaluations through external adapters.

Each adapter receives exactly one JSON object on stdin:

    {"request": "<raw authored request>"}

It must emit exactly one JSON routing decision on stdout. Expected decisions,
rationales, case identifiers, scoring policy, and variant relationships are
never sent to the adapter. Adapters run without a shell, with an allowlisted
environment and a disposable current directory.
"""

from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import hmac
import json
import math
import os
import re
import secrets
import signal
import subprocess
import sys
import tempfile
import threading
import time
from pathlib import Path
from typing import Any


_ADAPTER_SUPERVISOR_MODE = "--internal-adapter-supervisor"
_ADAPTER_SUPERVISOR_ARGV_ENV = "ROUTING_MODEL_INTERNAL_ADAPTER_ARGV"


def _run_adapter_supervisor() -> int:
    raw_argv = os.environ.pop(_ADAPTER_SUPERVISOR_ARGV_ENV, None)
    if raw_argv is None:
        return 125
    try:
        argv = json.loads(raw_argv)
    except (json.JSONDecodeError, TypeError):
        return 125
    if (
        not isinstance(argv, list)
        or not argv
        or any(not isinstance(argument, str) or not argument for argument in argv)
    ):
        return 125
    try:
        process = subprocess.Popen(
            argv,
            shell=False,
            env=dict(os.environ),
        )
    except (OSError, ValueError):
        return 126
    return int(process.wait())


if sys.argv[1:] == [_ADAPTER_SUPERVISOR_MODE]:
    raise SystemExit(_run_adapter_supervisor())


from jsonschema import Draft202012Validator, FormatChecker
from jsonschema.exceptions import SchemaError


ADAPTER_SCHEMA = "../schemas/routing-model-adapter.schema.json"
REPORT_SCHEMA = "../schemas/routing-model-evaluation-report.schema.json"
ROUTING_CATALOG_SCHEMA = "../schemas/routing-evaluations.schema.json"
DECISION_FIELDS = {
    "mode",
    "signals",
    "risk",
    "confirmation",
    "lead_skill",
    "supporting_skills",
}
PENALTY_FIELDS = {
    "wrong_mode",
    "missing_signal",
    "unnecessary_signal",
    "risk_underroute_per_level",
    "risk_overroute_per_level",
    "confirmation_underroute_per_level",
    "confirmation_overroute_per_level",
    "wrong_lead_skill",
    "missing_supporting_skill",
    "unnecessary_supporting_skill",
    "critical_underroute",
}
CANONICAL_ROUTING_THRESHOLD_TARGETS = frozenset(
    {
        "scoring.pass_score",
        "scoring.penalties.wrong_mode",
        "scoring.penalties.missing_signal",
        "scoring.penalties.unnecessary_signal",
        "scoring.penalties.risk_underroute_per_level",
        "scoring.penalties.risk_overroute_per_level",
        "scoring.penalties.confirmation_underroute_per_level",
        "scoring.penalties.confirmation_overroute_per_level",
        "scoring.penalties.wrong_lead_skill",
        "scoring.penalties.missing_supporting_skill",
        "scoring.penalties.unnecessary_supporting_skill",
        "scoring.penalties.critical_underroute",
        "manifest.routing_evaluations.minimum_cases",
        "coverage_requirements.maximum_cases",
        "coverage_requirements.minimum_cases_per_signal",
        "coverage_requirements.minimum_cases_per_mode",
        "coverage_requirements.minimum_minimal_route_cases",
    }
)
THRESHOLD_CLASSIFICATIONS = frozenset(
    {"derived", "safety_policy", "empirical", "implementation_limit"}
)
THRESHOLD_STATUSES = frozenset({"candidate", "accepted"})
THRESHOLD_POLICY_ID_PATTERN = re.compile(
    r"^[a-z][a-z0-9]*(?:-[a-z0-9]+)*$"
)
STATUS_ORDER = {"PASS": 0, "FAIL": 1, "INVALID": 2, "ERROR": 3}
ID_PATTERN = re.compile(r"^[a-z0-9]+(?:[-_][a-z0-9]+)*$")
ENV_NAME_PATTERN = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*$")
SECRET_FLAG_PATTERN = re.compile(
    r"(?i)^--?(?:api[-_]?key|access[-_]?token|auth[-_]?token|token|secret|"
    r"password|authorization|credential|client[-_]?secret|private[-_]?key|"
    r"key)(?:=|$)"
)
SECRET_ASSIGNMENT_PATTERN = re.compile(
    r"(?i)^(?:AWS_SECRET_ACCESS_KEY|[A-Z0-9_]*(?:API_KEY|ACCESS_TOKEN|"
    r"AUTH_TOKEN|CLIENT_SECRET|PRIVATE_KEY|PASSWORD))=.+$"
)
SECRET_VALUE_PATTERNS = (
    re.compile(r"(?i)\bbearer\s+[A-Za-z0-9._~+/=-]{8,}"),
    re.compile(r"\bsk-[A-Za-z0-9_-]{12,}"),
    re.compile(r"\bgh[pousr]_[A-Za-z0-9]{12,}"),
    re.compile(r"\bglpat-[A-Za-z0-9_-]{12,}"),
    re.compile(r"\bxox[baprs]-[A-Za-z0-9-]{12,}"),
    re.compile(r"\b(?:hf|npm)_[A-Za-z0-9_-]{12,}"),
    re.compile(r"\b(?:sk|rk)_live_[A-Za-z0-9]{12,}"),
    re.compile(r"\bAIza[A-Za-z0-9_-]{20,}"),
    re.compile(
        r"\beyJ[A-Za-z0-9_-]{8,}\.eyJ[A-Za-z0-9_-]{8,}\."
        r"[A-Za-z0-9_-]{8,}\b"
    ),
    re.compile(r"://[^/\s:@]+:[^@\s/]+@"),
)
PLACEHOLDER_PATTERN = re.compile(r"(?i)^replace-with(?:-|$)")
MAX_WORKSPACE_ENTRIES = 10_000
MAX_REPORTED_PATHS = 100


class ProcessCleanupError(RuntimeError):
    """Aggregate every retained-process cleanup failure."""

    def __init__(self, errors: list[Exception]) -> None:
        self.errors = tuple(errors)
        details = "; ".join(
            f"{type(error).__name__}: {error}" for error in errors
        )
        super().__init__(f"adapter process cleanup failed: {details}")


if os.name == "nt":
    import ctypes
    from ctypes import wintypes

    _CREATE_SUSPENDED = 0x00000004
    _CREATE_BREAKAWAY_FROM_JOB = 0x01000000
    _ERROR_ACCESS_DENIED = 5
    _ERROR_INVALID_PARAMETER = 87
    _JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE = 0x00002000
    _JOB_OBJECT_ASSOCIATE_COMPLETION_PORT_INFORMATION_CLASS = 7
    _JOB_OBJECT_BASIC_ACCOUNTING_INFORMATION_CLASS = 1
    _JOB_OBJECT_EXTENDED_LIMIT_INFORMATION_CLASS = 9
    _JOB_OBJECT_MSG_NEW_PROCESS = 6
    _JOB_TERMINATION_TIMEOUT_SECONDS = 5.0
    _PROCESS_TERMINATE = 0x0001
    _SYNCHRONIZE = 0x00100000
    _TH32CS_SNAPPROCESS = 0x00000002
    _WAIT_OBJECT_0 = 0x00000000
    _WAIT_TIMEOUT = 0x00000102

    class _JobObjectBasicLimitInformation(ctypes.Structure):
        _fields_ = [
            ("PerProcessUserTimeLimit", ctypes.c_longlong),
            ("PerJobUserTimeLimit", ctypes.c_longlong),
            ("LimitFlags", wintypes.DWORD),
            ("MinimumWorkingSetSize", ctypes.c_size_t),
            ("MaximumWorkingSetSize", ctypes.c_size_t),
            ("ActiveProcessLimit", wintypes.DWORD),
            ("Affinity", ctypes.c_size_t),
            ("PriorityClass", wintypes.DWORD),
            ("SchedulingClass", wintypes.DWORD),
        ]

    class _IoCounters(ctypes.Structure):
        _fields_ = [
            ("ReadOperationCount", ctypes.c_ulonglong),
            ("WriteOperationCount", ctypes.c_ulonglong),
            ("OtherOperationCount", ctypes.c_ulonglong),
            ("ReadTransferCount", ctypes.c_ulonglong),
            ("WriteTransferCount", ctypes.c_ulonglong),
            ("OtherTransferCount", ctypes.c_ulonglong),
        ]

    class _JobObjectExtendedLimitInformation(ctypes.Structure):
        _fields_ = [
            ("BasicLimitInformation", _JobObjectBasicLimitInformation),
            ("IoInfo", _IoCounters),
            ("ProcessMemoryLimit", ctypes.c_size_t),
            ("JobMemoryLimit", ctypes.c_size_t),
            ("PeakProcessMemoryUsed", ctypes.c_size_t),
            ("PeakJobMemoryUsed", ctypes.c_size_t),
        ]

    class _JobObjectBasicAccountingInformation(ctypes.Structure):
        _fields_ = [
            ("TotalUserTime", ctypes.c_longlong),
            ("TotalKernelTime", ctypes.c_longlong),
            ("ThisPeriodTotalUserTime", ctypes.c_longlong),
            ("ThisPeriodTotalKernelTime", ctypes.c_longlong),
            ("TotalPageFaultCount", wintypes.DWORD),
            ("TotalProcesses", wintypes.DWORD),
            ("ActiveProcesses", wintypes.DWORD),
            ("TotalTerminatedProcesses", wintypes.DWORD),
        ]

    class _JobObjectAssociateCompletionPort(ctypes.Structure):
        _fields_ = [
            ("CompletionKey", ctypes.c_void_p),
            ("CompletionPort", wintypes.HANDLE),
        ]

    class _ProcessEntry32W(ctypes.Structure):
        _fields_ = [
            ("dwSize", wintypes.DWORD),
            ("cntUsage", wintypes.DWORD),
            ("th32ProcessID", wintypes.DWORD),
            ("th32DefaultHeapID", ctypes.c_size_t),
            ("th32ModuleID", wintypes.DWORD),
            ("cntThreads", wintypes.DWORD),
            ("th32ParentProcessID", wintypes.DWORD),
            ("pcPriClassBase", ctypes.c_long),
            ("dwFlags", wintypes.DWORD),
            ("szExeFile", wintypes.WCHAR * 260),
        ]

    _kernel32 = ctypes.WinDLL("kernel32", use_last_error=True)
    _kernel32.CreateJobObjectW.argtypes = [ctypes.c_void_p, wintypes.LPCWSTR]
    _kernel32.CreateJobObjectW.restype = wintypes.HANDLE
    _kernel32.SetInformationJobObject.argtypes = [
        wintypes.HANDLE,
        ctypes.c_int,
        ctypes.c_void_p,
        wintypes.DWORD,
    ]
    _kernel32.SetInformationJobObject.restype = wintypes.BOOL
    _kernel32.AssignProcessToJobObject.argtypes = [
        wintypes.HANDLE,
        wintypes.HANDLE,
    ]
    _kernel32.AssignProcessToJobObject.restype = wintypes.BOOL
    _kernel32.TerminateJobObject.argtypes = [wintypes.HANDLE, wintypes.UINT]
    _kernel32.TerminateJobObject.restype = wintypes.BOOL
    _kernel32.QueryInformationJobObject.argtypes = [
        wintypes.HANDLE,
        ctypes.c_int,
        ctypes.c_void_p,
        wintypes.DWORD,
        ctypes.POINTER(wintypes.DWORD),
    ]
    _kernel32.QueryInformationJobObject.restype = wintypes.BOOL
    _kernel32.CreateIoCompletionPort.argtypes = [
        wintypes.HANDLE,
        wintypes.HANDLE,
        ctypes.c_size_t,
        wintypes.DWORD,
    ]
    _kernel32.CreateIoCompletionPort.restype = wintypes.HANDLE
    _kernel32.GetQueuedCompletionStatus.argtypes = [
        wintypes.HANDLE,
        ctypes.POINTER(wintypes.DWORD),
        ctypes.POINTER(ctypes.c_size_t),
        ctypes.POINTER(ctypes.c_void_p),
        wintypes.DWORD,
    ]
    _kernel32.GetQueuedCompletionStatus.restype = wintypes.BOOL
    _kernel32.CreateToolhelp32Snapshot.argtypes = [
        wintypes.DWORD,
        wintypes.DWORD,
    ]
    _kernel32.CreateToolhelp32Snapshot.restype = wintypes.HANDLE
    _kernel32.Process32FirstW.argtypes = [
        wintypes.HANDLE,
        ctypes.POINTER(_ProcessEntry32W),
    ]
    _kernel32.Process32FirstW.restype = wintypes.BOOL
    _kernel32.Process32NextW.argtypes = [
        wintypes.HANDLE,
        ctypes.POINTER(_ProcessEntry32W),
    ]
    _kernel32.Process32NextW.restype = wintypes.BOOL
    _kernel32.OpenProcess.argtypes = [
        wintypes.DWORD,
        wintypes.BOOL,
        wintypes.DWORD,
    ]
    _kernel32.OpenProcess.restype = wintypes.HANDLE
    _kernel32.TerminateProcess.argtypes = [wintypes.HANDLE, wintypes.UINT]
    _kernel32.TerminateProcess.restype = wintypes.BOOL
    _kernel32.WaitForSingleObject.argtypes = [wintypes.HANDLE, wintypes.DWORD]
    _kernel32.WaitForSingleObject.restype = wintypes.DWORD
    _kernel32.CloseHandle.argtypes = [wintypes.HANDLE]
    _kernel32.CloseHandle.restype = wintypes.BOOL
    _ntdll = ctypes.WinDLL("ntdll")
    _ntdll.NtResumeProcess.argtypes = [wintypes.HANDLE]
    _ntdll.NtResumeProcess.restype = ctypes.c_long

    def _windows_process_parents() -> dict[int, int]:
        invalid_handle = ctypes.c_void_p(-1).value
        snapshot = _kernel32.CreateToolhelp32Snapshot(
            _TH32CS_SNAPPROCESS,
            0,
        )
        if not snapshot or int(snapshot) == invalid_handle:
            raise OSError(
                ctypes.get_last_error(),
                "CreateToolhelp32Snapshot failed",
            )
        parents: dict[int, int] = {}
        try:
            entry = _ProcessEntry32W()
            entry.dwSize = ctypes.sizeof(entry)
            found = bool(_kernel32.Process32FirstW(snapshot, ctypes.byref(entry)))
            while found:
                parents[int(entry.th32ProcessID)] = int(
                    entry.th32ParentProcessID
                )
                found = bool(
                    _kernel32.Process32NextW(snapshot, ctypes.byref(entry))
                )
        finally:
            _kernel32.CloseHandle(snapshot)
        return parents

    class _WindowsProcessJob:
        """A kill-on-close job assigned before the adapter is resumed."""

        def __init__(self) -> None:
            self.assigned = False
            self.root_pid: int | None = None
            self.root_process_handle: Any | None = None
            self.descendant_handles: dict[int, list[Any]] = {}
            self.completion_port: Any | None = None
            self.handle = _kernel32.CreateJobObjectW(None, None)
            if not self.handle:
                raise OSError(
                    ctypes.get_last_error(),
                    "CreateJobObjectW failed",
                )
            limits = _JobObjectExtendedLimitInformation()
            limits.BasicLimitInformation.LimitFlags = (
                _JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE
            )
            if not _kernel32.SetInformationJobObject(
                self.handle,
                _JOB_OBJECT_EXTENDED_LIMIT_INFORMATION_CLASS,
                ctypes.byref(limits),
                ctypes.sizeof(limits),
            ):
                error = ctypes.get_last_error()
                _kernel32.CloseHandle(self.handle)
                self.handle = None
                raise OSError(error, "SetInformationJobObject failed")
            invalid_handle = ctypes.c_void_p(-1).value
            self.completion_port = _kernel32.CreateIoCompletionPort(
                wintypes.HANDLE(invalid_handle),
                None,
                0,
                1,
            )
            if not self.completion_port:
                error = ctypes.get_last_error()
                _kernel32.CloseHandle(self.handle)
                self.handle = None
                raise OSError(error, "CreateIoCompletionPort failed")
            association = _JobObjectAssociateCompletionPort(
                ctypes.c_void_p(1),
                self.completion_port,
            )
            if not _kernel32.SetInformationJobObject(
                self.handle,
                _JOB_OBJECT_ASSOCIATE_COMPLETION_PORT_INFORMATION_CLASS,
                ctypes.byref(association),
                ctypes.sizeof(association),
            ):
                error = ctypes.get_last_error()
                _kernel32.CloseHandle(self.completion_port)
                _kernel32.CloseHandle(self.handle)
                self.completion_port = None
                self.handle = None
                raise OSError(
                    error,
                    "job completion-port association failed",
                )

        def assign_and_resume(self, process: subprocess.Popen[bytes]) -> None:
            if self.handle is None:
                raise OSError("Windows process job is already closed")
            process_handle = wintypes.HANDLE(int(process._handle))  # type: ignore[attr-defined]
            if not _kernel32.AssignProcessToJobObject(
                self.handle,
                process_handle,
            ):
                raise OSError(
                    ctypes.get_last_error(),
                    "AssignProcessToJobObject failed",
                )
            self.assigned = True
            self.root_pid = process.pid
            # Borrowed from Popen; execute_adapter closes it only after the job.
            self.root_process_handle = process_handle
            resume_status = int(_ntdll.NtResumeProcess(process_handle))
            if resume_status != 0:
                raise OSError(
                    resume_status,
                    "NtResumeProcess failed",
                )

        def retain_descendant(self, pid: int) -> bool:
            if pid == self.root_pid or pid == os.getpid():
                return False
            for process_handle in self.descendant_handles.get(pid, []):
                wait_result = int(
                    _kernel32.WaitForSingleObject(process_handle, 0)
                )
                if wait_result == _WAIT_TIMEOUT:
                    return True
                if wait_result != _WAIT_OBJECT_0:
                    raise OSError(
                        ctypes.get_last_error(),
                        f"WaitForSingleObject failed for PID {pid}",
                    )
            ctypes.set_last_error(0)
            process_handle = _kernel32.OpenProcess(
                _PROCESS_TERMINATE | _SYNCHRONIZE,
                False,
                pid,
            )
            if not process_handle:
                error = ctypes.get_last_error()
                if error in (_ERROR_INVALID_PARAMETER, _ERROR_ACCESS_DENIED):
                    return False
                raise OSError(
                    error,
                    f"OpenProcess failed while retaining descendant PID {pid}",
                )
            self.descendant_handles.setdefault(pid, []).append(process_handle)
            return True

        def drain_completion_messages(self) -> None:
            if self.completion_port is None:
                return
            while True:
                message = wintypes.DWORD()
                completion_key = ctypes.c_size_t()
                process_id = ctypes.c_void_p()
                ctypes.set_last_error(0)
                received = bool(
                    _kernel32.GetQueuedCompletionStatus(
                        self.completion_port,
                        ctypes.byref(message),
                        ctypes.byref(completion_key),
                        ctypes.byref(process_id),
                        0,
                    )
                )
                if not received:
                    error = ctypes.get_last_error()
                    if error == _WAIT_TIMEOUT:
                        return
                    raise OSError(
                        error,
                        "GetQueuedCompletionStatus failed",
                    )
                # A completion message carries only a numeric PID, not an
                # identity-stable process handle. Treat it as a prompt to take
                # the Toolhelp snapshot below; never reopen a queued PID.

        def live_ancestry_pids(self) -> set[int]:
            ancestry: set[int] = set()
            if self.root_pid is not None and self.root_process_handle is not None:
                root_wait = int(
                    _kernel32.WaitForSingleObject(
                        self.root_process_handle,
                        0,
                    )
                )
                if root_wait == _WAIT_TIMEOUT:
                    ancestry.add(self.root_pid)
                elif root_wait != _WAIT_OBJECT_0:
                    raise OSError(
                        ctypes.get_last_error(),
                        "WaitForSingleObject failed for adapter root",
                    )
            for pid, process_handles in self.descendant_handles.items():
                for process_handle in process_handles:
                    wait_result = int(
                        _kernel32.WaitForSingleObject(process_handle, 0)
                    )
                    if wait_result == _WAIT_TIMEOUT:
                        ancestry.add(pid)
                        break
                    if wait_result != _WAIT_OBJECT_0:
                        raise OSError(
                            ctypes.get_last_error(),
                            f"WaitForSingleObject failed for PID {pid}",
                        )
            return ancestry

        def observe_descendants(self) -> None:
            if self.root_pid is None:
                return
            self.drain_completion_messages()
            parents = _windows_process_parents()
            ancestry = self.live_ancestry_pids()
            snapshot_descendants: set[int] = set()
            changed = True
            while changed:
                changed = False
                for pid, parent_pid in parents.items():
                    if (
                        parent_pid in ancestry
                        and pid != os.getpid()
                        and pid != self.root_pid
                    ):
                        snapshot_descendants.add(pid)
                        if pid not in ancestry:
                            ancestry.add(pid)
                            changed = True
            # Traverse the immutable parent snapshot first. A short-lived
            # broker may exit before its handle can be opened while its child
            # remains live; retaining each computed descendant afterwards
            # preserves the child without using the broker PID as a kill target.
            for pid in sorted(snapshot_descendants):
                self.retain_descendant(pid)

        def active_job_processes(self) -> int:
            if self.handle is None:
                return 0
            accounting = _JobObjectBasicAccountingInformation()
            returned_length = wintypes.DWORD()
            if not _kernel32.QueryInformationJobObject(
                self.handle,
                _JOB_OBJECT_BASIC_ACCOUNTING_INFORMATION_CLASS,
                ctypes.byref(accounting),
                ctypes.sizeof(accounting),
                ctypes.byref(returned_length),
            ):
                raise OSError(
                    ctypes.get_last_error(),
                    "QueryInformationJobObject failed",
                )
            return int(accounting.ActiveProcesses)

        def terminate_retained_descendants(self, deadline: float) -> None:
            if self.root_pid is None:
                return
            while True:
                self.observe_descendants()
                live_handles: list[tuple[int, Any]] = []
                for pid, process_handles in self.descendant_handles.items():
                    for process_handle in process_handles:
                        wait_result = int(
                            _kernel32.WaitForSingleObject(process_handle, 0)
                        )
                        if wait_result == _WAIT_OBJECT_0:
                            continue
                        if wait_result != _WAIT_TIMEOUT:
                            raise OSError(
                                ctypes.get_last_error(),
                                f"WaitForSingleObject failed for PID {pid}",
                            )
                        live_handles.append((pid, process_handle))
                if not live_handles:
                    return
                if time.monotonic() >= deadline:
                    raise TimeoutError(
                        "adapter descendant process tree did not terminate"
                    )

                termination_errors: dict[int, int] = {}
                for pid, process_handle in live_handles:
                    if not _kernel32.TerminateProcess(process_handle, 1):
                        termination_errors[id(process_handle)] = (
                            ctypes.get_last_error()
                        )
                cleanup_errors: list[Exception] = []
                for pid, process_handle in live_handles:
                    remaining_ms = max(
                        0,
                        int((deadline - time.monotonic()) * 1000),
                    )
                    wait_result = int(
                        _kernel32.WaitForSingleObject(
                            process_handle,
                            remaining_ms,
                        )
                    )
                    if wait_result == _WAIT_OBJECT_0:
                        continue
                    termination_error = termination_errors.get(
                        id(process_handle)
                    )
                    if termination_error is not None:
                        cleanup_errors.append(
                            OSError(
                                termination_error,
                                f"TerminateProcess failed for PID {pid}",
                            )
                        )
                    elif wait_result == _WAIT_TIMEOUT:
                        cleanup_errors.append(
                            TimeoutError(
                                "adapter descendant termination did not settle "
                                f"for PID {pid}"
                            )
                        )
                    else:
                        cleanup_errors.append(
                            OSError(
                                ctypes.get_last_error(),
                                "WaitForSingleObject failed during adapter "
                                f"descendant termination for PID {pid}",
                            )
                        )
                if cleanup_errors:
                    raise ProcessCleanupError(cleanup_errors)

        def close_descendant_handles(self) -> None:
            for process_handles in self.descendant_handles.values():
                for process_handle in process_handles:
                    _kernel32.CloseHandle(process_handle)
            self.descendant_handles.clear()

        def terminate(self) -> None:
            if self.handle is None:
                return
            handle = self.handle
            deadline = time.monotonic() + _JOB_TERMINATION_TIMEOUT_SECONDS
            try:
                self.observe_descendants()
                if not _kernel32.TerminateJobObject(handle, 1):
                    error = ctypes.get_last_error()
                    if self.active_job_processes() != 0:
                        raise OSError(error, "TerminateJobObject failed")
                while self.active_job_processes() != 0:
                    if time.monotonic() >= deadline:
                        raise TimeoutError(
                            "adapter job process tree did not terminate"
                        )
                    time.sleep(0.01)
                # A brokered Windows launcher can create a descendant outside
                # the assigned job. Live retained identities close that gap
                # without trusting an exited process's reusable numeric PID.
                self.terminate_retained_descendants(deadline)
            finally:
                self.close_descendant_handles()
                _kernel32.CloseHandle(handle)
                self.handle = None
                if self.completion_port is not None:
                    _kernel32.CloseHandle(self.completion_port)
                    self.completion_port = None
                self.root_process_handle = None

        def __del__(self) -> None:
            try:
                self.terminate()
            except Exception:
                pass

    def _windows_access_denied(error: OSError) -> bool:
        return getattr(error, "winerror", None) == _ERROR_ACCESS_DENIED

    def _close_windows_process_resources(process: Any) -> None:
        for stream_name in ("stdin", "stdout", "stderr"):
            stream = getattr(process, stream_name, None)
            if stream is not None and not stream.closed:
                try:
                    stream.close()
                except OSError:
                    pass
        process_handle = getattr(process, "_handle", None)
        if process_handle is not None:
            process_handle.Close()

    def _start_windows_adapter_process(
        argv: list[str],
        process_arguments: dict[str, Any],
        *,
        popen_factory: Any = None,
        job_factory: Any = None,
    ) -> tuple[subprocess.Popen[bytes], Any]:
        create_process = popen_factory or subprocess.Popen
        create_job = job_factory or _WindowsProcessJob
        base_creation_flags = _CREATE_SUSPENDED | subprocess.CREATE_NEW_PROCESS_GROUP
        for allow_breakaway in (True, False):
            job = create_job()
            process: subprocess.Popen[bytes] | None = None
            attempt_arguments = dict(process_arguments)
            attempt_arguments["creationflags"] = base_creation_flags | (
                _CREATE_BREAKAWAY_FROM_JOB if allow_breakaway else 0
            )
            try:
                process = create_process(argv, **attempt_arguments)
                job.assign_and_resume(process)
                return process, job
            except OSError as error:
                if process is not None:
                    try:
                        terminate_process_tree(process, job)
                    finally:
                        _close_windows_process_resources(process)
                else:
                    job.terminate()
                if (
                    allow_breakaway
                    and process is None
                    and _windows_access_denied(error)
                ):
                    continue
                raise
        raise AssertionError("unreachable Windows adapter start state")


def _supervisor_python_executable() -> str:
    return sys.executable



def _start_adapter_supervisor(
    adapter: dict[str, Any],
    process_arguments: dict[str, Any],
) -> tuple[subprocess.Popen[bytes], Any | None]:
    supervisor_arguments = dict(process_arguments)
    supervisor_environment = dict(supervisor_arguments["env"])
    supervisor_environment[_ADAPTER_SUPERVISOR_ARGV_ENV] = json.dumps(
        adapter["argv"],
        ensure_ascii=True,
        separators=(",", ":"),
    )
    supervisor_arguments["env"] = supervisor_environment
    supervisor_argv = [
        _supervisor_python_executable(),
        str(Path(__file__).resolve()),
        _ADAPTER_SUPERVISOR_MODE,
    ]
    if os.name == "nt":
        return _start_windows_adapter_process(  # type: ignore[name-defined]
            supervisor_argv,
            supervisor_arguments,
        )
    supervisor_arguments["start_new_session"] = True
    process = subprocess.Popen(
        supervisor_argv,
        **supervisor_arguments,
    )
    return process, None


class ConfigurationError(ValueError):
    """The runner input is invalid or unsafe to execute."""


def reject_json_constant(token: str) -> None:
    raise ValueError(f"non-standard JSON numeric constant is forbidden: {token}")


def reject_duplicate_keys(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    result: dict[str, Any] = {}
    for key, value in pairs:
        if key in result:
            raise ValueError(f"duplicate JSON property: {key}")
        result[key] = value
    return result


def parse_json(text: str, label: str) -> Any:
    try:
        return json.loads(
            text,
            parse_constant=reject_json_constant,
            object_pairs_hook=reject_duplicate_keys,
        )
    except (json.JSONDecodeError, ValueError) as error:
        raise ConfigurationError(f"{label} is not strict JSON: {error}") from error


def load_json(path: Path, label: str) -> tuple[Any, bytes]:
    try:
        content = path.read_bytes()
    except OSError as error:
        raise ConfigurationError(f"{label} could not be read") from error
    try:
        text = content.decode("utf-8")
    except UnicodeDecodeError as error:
        raise ConfigurationError(f"{label} must be UTF-8") from error
    return parse_json(text, label), content


def validate_document_schema(
    document: Any,
    schema_path: Path,
    label: str,
) -> None:
    schema, _ = load_json(schema_path, f"{label} schema")
    try:
        Draft202012Validator.check_schema(schema)
    except SchemaError as error:
        raise ConfigurationError(f"{label} schema is invalid") from error
    validator = Draft202012Validator(
        schema,
        format_checker=FormatChecker(),
    )
    errors = sorted(
        validator.iter_errors(document),
        key=lambda error: (
            tuple(str(part) for part in error.absolute_path),
            tuple(str(part) for part in error.absolute_schema_path),
        ),
    )
    if errors:
        path = ".".join(str(part) for part in errors[0].absolute_path)
        location = path if path else "<root>"
        raise ConfigurationError(
            f"{label} does not satisfy its Draft 2020-12 schema at {location}"
        )


def sha256_bytes(content: bytes) -> str:
    return hashlib.sha256(content).hexdigest()


def sha256_text(value: str) -> str:
    return hashlib.sha256(value.encode("utf-8")).hexdigest()


def utc_now() -> str:
    return (
        dt.datetime.now(dt.timezone.utc)
        .isoformat(timespec="milliseconds")
        .replace("+00:00", "Z")
    )


def is_number(value: Any) -> bool:
    return (
        isinstance(value, (int, float))
        and not isinstance(value, bool)
        and math.isfinite(float(value))
    )


def require_exact_keys(
    value: Any,
    required: set[str],
    label: str,
) -> dict[str, Any]:
    if not isinstance(value, dict):
        raise ConfigurationError(f"{label} must be an object")
    actual = set(value)
    missing = sorted(required - actual)
    extra = sorted(actual - required)
    if missing:
        raise ConfigurationError(f"{label} is missing properties: {', '.join(missing)}")
    if extra:
        raise ConfigurationError(f"{label} has unknown properties: {', '.join(extra)}")
    return value


def require_string(value: Any, label: str, *, placeholder_ok: bool = True) -> str:
    if not isinstance(value, str) or not value.strip():
        raise ConfigurationError(f"{label} must be a nonblank string")
    if not placeholder_ok and PLACEHOLDER_PATTERN.match(value.strip()):
        raise ConfigurationError(f"{label} still contains a template placeholder")
    return value


def require_iso_date(value: Any, label: str) -> dt.date:
    text = require_string(value, label)
    try:
        parsed = dt.date.fromisoformat(text)
    except ValueError as error:
        raise ConfigurationError(f"{label} must be YYYY-MM-DD") from error
    if parsed.isoformat() != text:
        raise ConfigurationError(f"{label} must be YYYY-MM-DD")
    return parsed


def require_string_set(value: Any, label: str) -> list[str]:
    if not isinstance(value, list):
        raise ConfigurationError(f"{label} must be an array")
    result: list[str] = []
    for index, item in enumerate(value):
        result.append(require_string(item, f"{label}[{index}]"))
    if len(result) != len(set(result)):
        raise ConfigurationError(f"{label} must not repeat values")
    return result


def load_manifest(root: Path) -> dict[str, Any]:
    manifest, _ = load_json(root / "governance-manifest.json", "governance manifest")
    required = {
        "pack_version",
        "risk_order",
        "confirmation_order",
        "task_modes",
        "routing_signals",
        "risk_overlays",
        "skills",
        "routing_evaluations",
    }
    if not isinstance(manifest, dict) or not required.issubset(manifest):
        raise ConfigurationError("governance manifest lacks routing fields")
    require_string(manifest["pack_version"], "governance manifest pack_version")
    require_string_set(manifest["risk_order"], "governance manifest risk_order")
    require_string_set(
        manifest["confirmation_order"],
        "governance manifest confirmation_order",
    )
    if not isinstance(manifest["task_modes"], dict) or not manifest["task_modes"]:
        raise ConfigurationError("governance manifest task_modes must be an object")
    if not isinstance(manifest["routing_signals"], dict) or not manifest["routing_signals"]:
        raise ConfigurationError("governance manifest routing_signals must be an object")
    if not isinstance(manifest["risk_overlays"], list):
        raise ConfigurationError("governance manifest risk_overlays must be an array")
    if not isinstance(manifest["skills"], list):
        raise ConfigurationError("governance manifest skills must be an array")
    routing_evaluations = manifest["routing_evaluations"]
    if not isinstance(routing_evaluations, dict):
        raise ConfigurationError(
            "governance manifest routing_evaluations must be an object"
        )
    minimum_cases = routing_evaluations.get("minimum_cases")
    if (
        not isinstance(minimum_cases, int)
        or isinstance(minimum_cases, bool)
        or minimum_cases < 1
    ):
        raise ConfigurationError(
            "governance manifest routing_evaluations.minimum_cases must be "
            "a positive integer"
        )
    return manifest


def skill_names(manifest: dict[str, Any]) -> set[str]:
    names: set[str] = set()
    for skill in manifest["skills"]:
        if not isinstance(skill, dict) or not isinstance(skill.get("name"), str):
            raise ConfigurationError("governance manifest contains an invalid skill")
        names.add(skill["name"])
    return names


def compose_decision(
    manifest: dict[str, Any],
    signals: list[str],
) -> dict[str, Any]:
    risk_order = list(manifest["risk_order"])
    confirmation_order = list(manifest["confirmation_order"])
    risk_rank = {name: index for index, name in enumerate(risk_order)}
    confirmation_rank = {
        name: index for index, name in enumerate(confirmation_order)
    }
    computed_risk_rank = 0
    computed_confirmation_rank = 0
    lead_skill: str | None = None
    supporting: list[str] = []

    for signal_name in signals:
        signal_definition = manifest["routing_signals"][signal_name]
        signal_risk = signal_definition["minimum_risk"]
        signal_confirmation = signal_definition["confirmation"]
        computed_risk_rank = max(computed_risk_rank, risk_rank[signal_risk])
        computed_confirmation_rank = max(
            computed_confirmation_rank,
            confirmation_rank[signal_confirmation],
        )
        candidate_lead = signal_definition.get("lead_skill")
        if candidate_lead is not None:
            if lead_skill is None:
                lead_skill = candidate_lead
            elif candidate_lead != lead_skill:
                supporting.append(candidate_lead)
        supporting.extend(signal_definition.get("supporting_skills", []))

    for overlay in manifest["risk_overlays"]:
        if computed_risk_rank >= risk_rank[overlay["minimum_risk"]]:
            supporting.extend(overlay.get("supporting_skills", []))

    return {
        "risk": risk_order[computed_risk_rank],
        "confirmation": confirmation_order[computed_confirmation_rank],
        "lead_skill": lead_skill,
        "supporting_skills": sorted(
            {name for name in supporting if name != lead_skill}
        ),
    }


def validate_decision(
    value: Any,
    manifest: dict[str, Any],
) -> tuple[dict[str, Any] | None, list[str]]:
    failures: list[str] = []
    if not isinstance(value, dict):
        return None, ["decision_not_object"]
    if set(value) != DECISION_FIELDS:
        return None, ["decision_shape"]

    mode = value.get("mode")
    risk = value.get("risk")
    confirmation = value.get("confirmation")
    lead = value.get("lead_skill")
    if not isinstance(mode, str) or mode not in manifest["task_modes"]:
        failures.append("unknown_mode")
    if not isinstance(risk, str) or risk not in manifest["risk_order"]:
        failures.append("unknown_risk")
    if (
        not isinstance(confirmation, str)
        or confirmation not in manifest["confirmation_order"]
    ):
        failures.append("unknown_confirmation")
    known_skills = skill_names(manifest)
    if lead is not None and (not isinstance(lead, str) or lead not in known_skills):
        failures.append("unknown_lead_skill")

    signals_value = value.get("signals")
    supports_value = value.get("supporting_skills")
    if not isinstance(signals_value, list):
        failures.append("signals_not_array")
        signals: list[str] = []
    else:
        signals = list(signals_value)
        if any(not isinstance(item, str) or not item for item in signals):
            failures.append("invalid_signal_value")
        elif len(signals) != len(set(signals)):
            failures.append("duplicate_signal")
        elif any(item not in manifest["routing_signals"] for item in signals):
            failures.append("unknown_signal")

    if not isinstance(supports_value, list):
        failures.append("supporting_skills_not_array")
        supports: list[str] = []
    else:
        supports = list(supports_value)
        if any(not isinstance(item, str) or not item for item in supports):
            failures.append("invalid_supporting_skill_value")
        elif len(supports) != len(set(supports)):
            failures.append("duplicate_supporting_skill")
        elif any(item not in known_skills for item in supports):
            failures.append("unknown_supporting_skill")

    if failures:
        return None, sorted(set(failures))

    required_signals = list(
        manifest["task_modes"][mode].get("required_signals", [])
    )
    all_task_mode_signals = {
        signal_name
        for definition in manifest["task_modes"].values()
        for signal_name in definition.get("required_signals", [])
    }
    if any(required not in signals for required in required_signals):
        failures.append("missing_mode_signal")
    if any(
        prohibited in signals
        for prohibited in all_task_mode_signals
        if prohibited not in required_signals
    ):
        failures.append("prohibited_mode_signal")

    composed = compose_decision(manifest, signals)
    if risk != composed["risk"]:
        failures.append("composed_risk_mismatch")
    if confirmation != composed["confirmation"]:
        failures.append("composed_confirmation_mismatch")
    if lead != composed["lead_skill"]:
        failures.append("composed_lead_skill_mismatch")
    if set(supports) != set(composed["supporting_skills"]):
        failures.append("composed_supporting_skills_mismatch")

    if failures:
        return None, sorted(set(failures))

    normalized = {
        "mode": mode,
        "signals": signals,
        "risk": risk,
        "confirmation": confirmation,
        "lead_skill": lead,
        "supporting_skills": supports,
    }
    return normalized, []


def validate_catalog(
    catalog: Any,
    manifest: dict[str, Any],
) -> tuple[
    dict[str, Any],
    list[dict[str, Any]],
    list[dict[str, Any]],
]:
    if not isinstance(catalog, dict):
        raise ConfigurationError("routing catalog must be an object")
    schema_version = catalog.get("schema_version")
    if schema_version != 2 or isinstance(schema_version, bool):
        raise ConfigurationError(
            "routing catalog schema_version must be integer 2"
        )
    catalog_fields = {
        "$schema",
        "schema_version",
        "oracle",
        "threshold_policies",
        "coverage_requirements",
        "scoring",
        "cases",
    }
    document = require_exact_keys(catalog, catalog_fields, "routing catalog")
    if document["$schema"] != ROUTING_CATALOG_SCHEMA:
        raise ConfigurationError("routing catalog has the wrong v2 $schema")

    oracle = require_exact_keys(
        document["oracle"],
        {"kind", "owner", "basis", "reviewed_on", "pack_version"},
        "routing catalog oracle",
    )
    for field in ("kind", "owner", "basis", "reviewed_on", "pack_version"):
        require_string(oracle[field], f"routing catalog oracle {field}")
    require_iso_date(
        oracle["reviewed_on"],
        "routing catalog oracle reviewed_on",
    )
    if oracle["kind"] != "human_semantic":
        raise ConfigurationError(
            "routing catalog oracle kind must be human_semantic"
        )
    if oracle["pack_version"] != manifest["pack_version"]:
        raise ConfigurationError(
            "routing catalog oracle pack_version does not match the manifest"
        )

    threshold_policies = document["threshold_policies"]
    if not isinstance(threshold_policies, list) or not threshold_policies:
        raise ConfigurationError(
            "routing catalog threshold_policies must be a nonempty array"
        )
    threshold_ids: set[str] = set()
    target_owners: dict[str, list[dict[str, Any]]] = {}
    for index, raw_policy in enumerate(threshold_policies):
        policy = require_exact_keys(
            raw_policy,
            {
                "id",
                "classification",
                "status",
                "owner",
                "basis",
                "evidence_refs",
                "reviewed_on",
                "review_by",
                "targets",
            },
            f"routing catalog threshold policy {index}",
        )
        for field in (
            "id",
            "classification",
            "status",
            "owner",
            "basis",
            "reviewed_on",
            "review_by",
        ):
            require_string(
                policy[field],
                f"routing catalog threshold policy {index} {field}",
            )
        if policy["id"] in threshold_ids:
            raise ConfigurationError(
                "routing catalog threshold policy ids must be unique"
            )
        if not THRESHOLD_POLICY_ID_PATTERN.fullmatch(policy["id"]):
            raise ConfigurationError(
                "routing catalog threshold policy id must be kebab-case"
            )
        threshold_ids.add(policy["id"])
        if policy["classification"] not in THRESHOLD_CLASSIFICATIONS:
            raise ConfigurationError(
                "routing catalog threshold policy classification is invalid"
            )
        if policy["status"] not in THRESHOLD_STATUSES:
            raise ConfigurationError(
                "routing catalog threshold policy status is invalid"
            )
        if len(policy["basis"]) < 20:
            raise ConfigurationError(
                "routing catalog threshold policy basis must be at least "
                "20 characters"
            )
        evidence_refs = require_string_set(
            policy["evidence_refs"],
            f"routing catalog threshold policy {index} evidence_refs",
        )
        if policy["classification"] == "empirical" and not evidence_refs:
            raise ConfigurationError(
                "routing catalog empirical threshold policy requires "
                "evidence_refs"
            )
        require_iso_date(
            policy["reviewed_on"],
            f"routing catalog threshold policy {index} reviewed_on",
        )
        review_by = require_iso_date(
            policy["review_by"],
            f"routing catalog threshold policy {index} review_by",
        )
        if review_by < dt.datetime.now(dt.timezone.utc).date():
            raise ConfigurationError(
                "routing catalog threshold policy review_by is expired"
            )
        targets = require_string_set(
            policy["targets"],
            f"routing catalog threshold policy {index} targets",
        )
        if not targets:
            raise ConfigurationError(
                "routing catalog threshold policy targets must be nonempty"
            )
        for target in targets:
            target_owners.setdefault(target, []).append(policy)

    actual_targets = set(target_owners)
    missing_targets = sorted(
        CANONICAL_ROUTING_THRESHOLD_TARGETS - actual_targets
    )
    unknown_targets = sorted(
        actual_targets - CANONICAL_ROUTING_THRESHOLD_TARGETS
    )
    if missing_targets or unknown_targets:
        details: list[str] = []
        if missing_targets:
            details.append(f"missing: {', '.join(missing_targets)}")
        if unknown_targets:
            details.append(f"unknown: {', '.join(unknown_targets)}")
        raise ConfigurationError(
            "routing catalog threshold policy targets must exactly cover the "
            f"canonical target set ({'; '.join(details)})"
        )
    duplicate_targets = sorted(
        target
        for target, owners in target_owners.items()
        if len(owners) != 1
    )
    if duplicate_targets:
        raise ConfigurationError(
            "routing catalog threshold policy targets must have exactly one "
            f"owner: {', '.join(duplicate_targets)}"
        )
    critical_target = "scoring.penalties.critical_underroute"
    critical_owner = target_owners[critical_target][0]
    if critical_owner["classification"] != "derived":
        raise ConfigurationError(
            "routing catalog critical_underroute target must be owned by a "
            "derived threshold policy"
        )

    coverage = require_exact_keys(
        document["coverage_requirements"],
        {
            "maximum_cases",
            "minimum_cases_per_signal",
            "minimum_cases_per_mode",
            "minimum_minimal_route_cases",
        },
        "routing catalog coverage_requirements",
    )
    for field, value in coverage.items():
        if (
            not isinstance(value, int)
            or isinstance(value, bool)
            or value < 1
        ):
            raise ConfigurationError(
                f"routing catalog coverage requirement {field} "
                "must be a positive integer"
            )

    scoring = require_exact_keys(
        document["scoring"],
        {"pass_score", "penalties"},
        "routing catalog scoring",
    )
    pass_score = scoring["pass_score"]
    if not is_number(pass_score) or not 1 <= float(pass_score) <= 100:
        raise ConfigurationError("routing catalog pass_score must be from 1 to 100")
    penalties = require_exact_keys(
        scoring["penalties"],
        PENALTY_FIELDS,
        "routing catalog penalties",
    )
    for name, value in penalties.items():
        if not is_number(value) or not 0 <= float(value) <= 100:
            raise ConfigurationError(
                f"routing catalog penalty {name} must be from 0 to 100"
            )
    if float(penalties["critical_underroute"]) != 100:
        raise ConfigurationError(
            "routing catalog critical_underroute penalty must be 100"
        )
    if float(penalties["wrong_mode"]) <= 100 - float(pass_score):
        raise ConfigurationError("routing catalog wrong_mode penalty is compensatory")
    if float(penalties["missing_signal"]) <= 100 - float(pass_score):
        raise ConfigurationError(
            "routing catalog missing_signal penalty is compensatory"
        )

    raw_cases = document["cases"]
    if not isinstance(raw_cases, list) or not raw_cases:
        raise ConfigurationError("routing catalog cases must be a nonempty array")
    case_ids: set[str] = set()
    cases: list[dict[str, Any]] = []
    inline_variants: list[dict[str, Any]] = []
    for index, raw_case in enumerate(raw_cases):
        if not isinstance(raw_case, dict):
            raise ConfigurationError(f"routing catalog case {index} must be an object")
        required_case_fields = {"id", "request", "rationale", "expected"}
        allowed_case_fields = required_case_fields | {"variants"}
        missing_case_fields = sorted(required_case_fields - set(raw_case))
        extra_case_fields = sorted(set(raw_case) - allowed_case_fields)
        if missing_case_fields:
            raise ConfigurationError(
                "routing catalog case is missing properties: "
                + ", ".join(missing_case_fields)
            )
        if extra_case_fields:
            raise ConfigurationError(
                "routing catalog case has unknown properties: "
                + ", ".join(extra_case_fields)
            )
        case = raw_case
        case_id = require_string(case["id"], f"routing catalog case {index} id")
        if not re.match(r"^[a-z0-9]+(?:-[a-z0-9]+)*$", case_id):
            raise ConfigurationError("routing catalog case id must be kebab-case")
        if case_id in case_ids:
            raise ConfigurationError("routing catalog contains duplicate case ids")
        case_ids.add(case_id)
        request = require_string(
            case["request"],
            f"routing catalog case {index} request",
        )
        rationale = require_string(
            case["rationale"],
            f"routing catalog case {index} rationale",
        )
        if len(request.strip()) < 20 or len(rationale.strip()) < 20:
            raise ConfigurationError(
                "routing catalog requests and rationales must be at least 20 characters"
            )
        expected, failures = validate_decision(case["expected"], manifest)
        if failures or expected is None:
            raise ConfigurationError(
                "routing catalog contains an invalid expected decision"
            )
        cases.append(
            {
                "id": case_id,
                "request": request,
                "expected": expected,
                "variant_of": None,
            }
        )
        raw_inline_variants = case.get("variants", [])
        if not isinstance(raw_inline_variants, list):
            raise ConfigurationError(
                "routing catalog case variants must be an array"
            )
        for variant_index, raw_variant in enumerate(raw_inline_variants):
            variant = require_exact_keys(
                raw_variant,
                {"id", "request"},
                f"routing catalog case {index} variant {variant_index}",
            )
            variant_id = require_string(
                variant["id"],
                f"routing catalog case {index} variant {variant_index} id",
            )
            variant_request = require_string(
                variant["request"],
                f"routing catalog case {index} variant {variant_index} request",
            )
            if not re.match(r"^[a-z0-9]+(?:-[a-z0-9]+)*$", variant_id):
                raise ConfigurationError(
                    "routing catalog inline variant id must be kebab-case"
                )
            if len(variant_request.strip()) < 20:
                raise ConfigurationError(
                    "routing catalog inline variant request must be at least "
                    "20 characters"
                )
            inline_variants.append(
                {
                    "id": variant_id,
                    "request": variant_request,
                    "expected": expected,
                    "variant_of": case_id,
                }
            )

    all_ids = [case["id"] for case in cases] + [
        variant["id"] for variant in inline_variants
    ]
    if len(all_ids) != len(set(all_ids)):
        raise ConfigurationError(
            "routing catalog base and inline variant ids must be globally unique"
        )

    minimum_cases = int(manifest["routing_evaluations"]["minimum_cases"])
    maximum_cases = int(coverage["maximum_cases"])
    base_case_count = len(cases)
    if not minimum_cases <= base_case_count <= maximum_cases:
        raise ConfigurationError(
            "routing catalog base-case count must be between manifest "
            f"minimum {minimum_cases} and catalog maximum {maximum_cases}; "
            f"found {base_case_count}"
        )

    signal_coverage = {
        signal_name: 0 for signal_name in manifest["routing_signals"]
    }
    mode_coverage = {mode_name: 0 for mode_name in manifest["task_modes"]}
    minimal_route_cases = 0
    for case in cases:
        expected = case["expected"]
        mode = expected["mode"]
        mode_coverage[mode] += 1
        for signal_name in expected["signals"]:
            signal_coverage[signal_name] += 1
        required_signals = set(
            manifest["task_modes"][mode].get("required_signals", [])
        )
        if set(expected["signals"]) == required_signals:
            minimal_route_cases += 1

    signal_floor = int(coverage["minimum_cases_per_signal"])
    undercovered_signals = sorted(
        signal_name
        for signal_name, count in signal_coverage.items()
        if count < signal_floor
    )
    if undercovered_signals:
        raise ConfigurationError(
            "routing catalog signals do not meet the base-case coverage "
            f"floor {signal_floor}: {', '.join(undercovered_signals)}"
        )
    mode_floor = int(coverage["minimum_cases_per_mode"])
    undercovered_modes = sorted(
        mode_name
        for mode_name, count in mode_coverage.items()
        if count < mode_floor
    )
    if undercovered_modes:
        raise ConfigurationError(
            "routing catalog task modes do not meet the base-case coverage "
            f"floor {mode_floor}: {', '.join(undercovered_modes)}"
        )
    minimal_route_floor = int(coverage["minimum_minimal_route_cases"])
    if minimal_route_cases < minimal_route_floor:
        raise ConfigurationError(
            "routing catalog minimal-route base cases do not meet the "
            f"coverage floor {minimal_route_floor}; found {minimal_route_cases}"
        )
    return document, cases, inline_variants


def load_variants(
    path: Path | None,
    base_cases: list[dict[str, Any]],
    existing_variants: list[dict[str, Any]],
) -> tuple[list[dict[str, Any]], str | None]:
    if path is None:
        return [], None
    document, content = load_json(path, "routing variants")
    document = require_exact_keys(
        document,
        {"schema_version", "variants"},
        "routing variants",
    )
    if document["schema_version"] != 1 or isinstance(
        document["schema_version"], bool
    ):
        raise ConfigurationError("routing variants schema_version must be integer 1")
    raw_variants = document["variants"]
    if not isinstance(raw_variants, list):
        raise ConfigurationError("routing variants variants must be an array")

    base_by_id = {case["id"]: case for case in base_cases}
    known_ids = set(base_by_id) | {
        variant["id"] for variant in existing_variants
    }
    variants: list[dict[str, Any]] = []
    for index, raw_variant in enumerate(raw_variants):
        variant = require_exact_keys(
            raw_variant,
            {"id", "base_case_id", "request"},
            f"routing variant {index}",
        )
        variant_id = require_string(variant["id"], f"routing variant {index} id")
        base_id = require_string(
            variant["base_case_id"],
            f"routing variant {index} base_case_id",
        )
        request = require_string(
            variant["request"],
            f"routing variant {index} request",
        )
        if not re.match(r"^[a-z0-9]+(?:-[a-z0-9]+)*$", variant_id):
            raise ConfigurationError("routing variant id must be kebab-case")
        if variant_id in known_ids:
            raise ConfigurationError("routing variant id must be unique")
        if base_id not in base_by_id:
            raise ConfigurationError("routing variant references an unknown base case")
        if len(request.strip()) < 20:
            raise ConfigurationError(
                "routing variant request must be at least 20 characters"
            )
        known_ids.add(variant_id)
        variants.append(
            {
                "id": variant_id,
                "request": request,
                "expected": base_by_id[base_id]["expected"],
                "variant_of": base_id,
            }
        )
    return variants, sha256_bytes(content)


def enforce_total_case_limit(
    cases: list[dict[str, Any]],
    catalog: dict[str, Any],
) -> None:
    maximum_cases = int(
        catalog["coverage_requirements"]["maximum_cases"]
    )
    if len(cases) > maximum_cases:
        raise ConfigurationError(
            "routing catalog total runnable case count exceeds "
            f"maximum_cases {maximum_cases}; found {len(cases)}"
        )


def serialize_request_envelope(
    request: str,
    max_request_bytes: int,
) -> bytes:
    envelope = (
        json.dumps({"request": request}, ensure_ascii=False) + "\n"
    ).encode("utf-8")
    if len(envelope) > max_request_bytes:
        raise ConfigurationError(
            "serialized request envelope exceeds --max-request-bytes"
        )
    return envelope


def argv_contains_secret(argv: list[str]) -> bool:
    for argument in argv:
        if (
            SECRET_FLAG_PATTERN.match(argument)
            or SECRET_ASSIGNMENT_PATTERN.match(argument)
        ):
            return True
        if any(pattern.search(argument) for pattern in SECRET_VALUE_PATTERNS):
            return True
        if "\x00" in argument or "\n" in argument or "\r" in argument:
            return True
    return False


def validate_adapter(
    document: Any,
    content: bytes,
    source_environment: dict[str, str],
) -> dict[str, Any]:
    adapter = require_exact_keys(
        document,
        {
            "$schema",
            "schema_version",
            "id",
            "argv",
            "environment_allowlist",
            "model",
            "instruction_binding",
        },
        "adapter configuration",
    )
    if adapter["$schema"] != ADAPTER_SCHEMA:
        raise ConfigurationError("adapter configuration has the wrong $schema")
    if adapter["schema_version"] != 1 or isinstance(
        adapter["schema_version"], bool
    ):
        raise ConfigurationError("adapter schema_version must be integer 1")
    adapter_id = require_string(
        adapter["id"],
        "adapter id",
        placeholder_ok=False,
    )
    if not ID_PATTERN.match(adapter_id):
        raise ConfigurationError("adapter id must use lowercase letters and separators")

    argv_value = adapter["argv"]
    if not isinstance(argv_value, list) or not argv_value:
        raise ConfigurationError("adapter argv must be a nonempty array")
    argv = [
        require_string(item, f"adapter argv[{index}]", placeholder_ok=False)
        for index, item in enumerate(argv_value)
    ]
    if argv_contains_secret(argv):
        raise ConfigurationError(
            "best-effort secret scan flagged adapter argv; adapter "
            "configurations must remain secret-free, use environment_allowlist "
            "for variable names, and require external secret scanning"
        )

    allowlist = require_string_set(
        adapter["environment_allowlist"],
        "adapter environment_allowlist",
    )
    for name in allowlist:
        if not ENV_NAME_PATTERN.match(name) or "=" in name:
            raise ConfigurationError(
                "adapter environment_allowlist contains an invalid name"
            )
        if name not in source_environment:
            raise ConfigurationError(
                "adapter environment_allowlist names an unavailable variable"
            )

    model = require_exact_keys(
        adapter["model"],
        {"provider", "name", "version", "agent_surface"},
        "adapter model",
    )
    normalized_model: dict[str, str] = {}
    for field in ("provider", "name", "version", "agent_surface"):
        normalized_model[field] = require_string(
            model[field],
            f"adapter model {field}",
            placeholder_ok=False,
        )
    instruction_binding = require_string(
        adapter["instruction_binding"],
        "adapter instruction_binding",
        placeholder_ok=False,
    )
    return {
        "id": adapter_id,
        "argv": argv,
        "environment_allowlist": allowlist,
        "model": normalized_model,
        "instruction_binding": instruction_binding,
        "config_sha256": sha256_bytes(content),
    }


def sanitized_environment(
    allowlist: list[str],
    source_environment: dict[str, str],
    temporary_directory: Path,
) -> dict[str, str]:
    base_names = {
        "PATH",
        "SystemRoot",
        "WINDIR",
        "COMSPEC",
        "PATHEXT",
        "TEMP",
        "TMP",
        "TMPDIR",
        "LANG",
        "LC_ALL",
    }
    result = {
        name: source_environment[name]
        for name in sorted(base_names | set(allowlist))
        if name in source_environment
    }
    result["PYTHONIOENCODING"] = "utf-8"
    result["PYTHONDONTWRITEBYTECODE"] = "1"
    temporary_path = str(temporary_directory)
    result["TEMP"] = temporary_path
    result["TMP"] = temporary_path
    result["TMPDIR"] = temporary_path
    return result


def snapshot_workspace(
    root: Path,
) -> tuple[dict[str, tuple[str, int, int, int]], bool]:
    snapshot: dict[str, tuple[str, int, int, int]] = {}
    stack = [root]
    overflow = False
    while stack:
        directory = stack.pop()
        try:
            entries = sorted(os.scandir(directory), key=lambda entry: entry.name)
        except OSError:
            overflow = True
            continue
        for entry in entries:
            relative = Path(entry.path).relative_to(root).as_posix()
            try:
                stat_result = entry.stat(follow_symlinks=False)
                if entry.is_symlink():
                    kind = "symlink"
                elif entry.is_dir(follow_symlinks=False):
                    kind = "directory"
                elif entry.is_file(follow_symlinks=False):
                    kind = "file"
                else:
                    kind = "other"
                snapshot[relative] = (
                    kind,
                    int(stat_result.st_size),
                    int(stat_result.st_mode),
                    int(stat_result.st_mtime_ns),
                )
                if kind == "directory":
                    stack.append(Path(entry.path))
            except OSError:
                snapshot[relative] = ("unreadable", 0, 0, 0)
            if len(snapshot) >= MAX_WORKSPACE_ENTRIES:
                overflow = True
                return snapshot, overflow
    return snapshot, overflow


def terminate_process_tree(
    process: subprocess.Popen[bytes],
    windows_job: Any | None,
) -> None:
    """Terminate Windows-observed descendants or the initial POSIX process group.

    POSIX containment does not claim control over a deliberate setsid escape.
    """

    if os.name == "nt":
        if windows_job is not None:
            assigned_to_job = bool(windows_job.assigned)
            windows_job.terminate()
        else:
            assigned_to_job = False
        if (not assigned_to_job) and process.poll() is None:
            try:
                process.kill()
            except OSError:
                pass
        try:
            process.wait(timeout=1)
        except subprocess.TimeoutExpired:
            try:
                process.kill()
                process.wait(timeout=1)
            except (OSError, subprocess.TimeoutExpired):
                pass
        return

    try:
        os.killpg(process.pid, signal.SIGTERM)
    except ProcessLookupError:
        pass
    except OSError:
        if process.poll() is None:
            try:
                process.terminate()
            except OSError:
                pass
    try:
        process.wait(timeout=0.25)
    except subprocess.TimeoutExpired:
        pass
    # The adapter parent may already be gone while descendants retain the
    # process group and inherited pipes. Always escalate the group itself.
    try:
        os.killpg(process.pid, signal.SIGKILL)
    except ProcessLookupError:
        pass
    except OSError:
        if process.poll() is None:
            try:
                process.kill()
            except OSError:
                pass
    try:
        process.wait(timeout=1)
    except subprocess.TimeoutExpired:
        try:
            process.kill()
            process.wait(timeout=1)
        except (OSError, subprocess.TimeoutExpired):
            pass


def execute_adapter(
    adapter: dict[str, Any],
    request_envelope: bytes,
    timeout_seconds: float,
    max_output_bytes: int,
) -> tuple[dict[str, Any], bytes, bytes, dict[str, Any], str | None]:
    stdout_buffer = bytearray()
    stderr_buffer = bytearray()
    observed = {"stdout": 0, "stderr": 0}
    output_limited_event = threading.Event()
    lock = threading.Lock()
    process: subprocess.Popen[bytes] | None = None
    process_exit_code: int | None = None
    windows_job: Any | None = None
    windows_tracker_thread: threading.Thread | None = None
    windows_tracker_stop = threading.Event()
    windows_tracker_ready = threading.Event()
    windows_tracker_errors: list[OSError] = []
    stdin_writer_thread: threading.Thread | None = None
    stdin_writer_errors: list[Exception] = []
    stdin_writer_done = threading.Event()
    timed_out = False
    process_error: str | None = None
    deadline = time.monotonic() + timeout_seconds

    def track_windows_descendants() -> None:
        tracker_started = time.monotonic()
        while not windows_tracker_stop.is_set():
            try:
                if windows_job is not None:
                    windows_job.observe_descendants()
            except OSError as error:
                windows_tracker_errors.append(error)
                windows_tracker_ready.set()
                return
            if (
                windows_job is None
                or windows_job.descendant_handles
                or time.monotonic() - tracker_started >= 0.25
            ):
                windows_tracker_ready.set()
            windows_tracker_stop.wait(0.025)

    def stop_windows_tracker() -> None:
        windows_tracker_stop.set()
        if windows_tracker_thread is not None:
            windows_tracker_thread.join(timeout=_JOB_TERMINATION_TIMEOUT_SECONDS)
            if windows_tracker_thread.is_alive():
                raise TimeoutError(
                    "Windows adapter process-tree tracker did not stop"
                )

    with tempfile.TemporaryDirectory(prefix="routing-model-eval-") as cwd_name:
        cwd = Path(cwd_name)
        before, before_overflow = snapshot_workspace(cwd)
        try:
            process_arguments: dict[str, Any] = {
                "cwd": cwd,
                "env": sanitized_environment(
                    adapter["environment_allowlist"],
                    dict(os.environ),
                    cwd,
                ),
                "stdin": subprocess.PIPE,
                "stdout": subprocess.PIPE,
                "stderr": subprocess.PIPE,
                "shell": False,
            }
            process, windows_job = _start_adapter_supervisor(
                adapter,
                process_arguments,
            )
            if windows_job is not None:
                windows_tracker_thread = threading.Thread(
                    target=track_windows_descendants,
                    daemon=True,
                )
                windows_tracker_thread.start()
                tracker_wait = max(
                    0.0,
                    min(1.0, deadline - time.monotonic()),
                )
                windows_tracker_ready.wait(timeout=tracker_wait)
        except (OSError, ValueError):
            process_error = "process_start"
            if process is not None:
                terminate_process_tree(process, windows_job)
            elif windows_job is not None:
                windows_job.terminate()

        reader_threads: list[threading.Thread] = []

        def read_stream(
            stream_name: str,
            stream: Any,
            target: bytearray,
        ) -> None:
            try:
                while True:
                    chunk = stream.read(4096)
                    if not chunk:
                        break
                    with lock:
                        observed[stream_name] += len(chunk)
                        stored_total = len(stdout_buffer) + len(stderr_buffer)
                        remaining = max(0, max_output_bytes - stored_total)
                        if remaining:
                            target.extend(chunk[:remaining])
                        if observed["stdout"] + observed["stderr"] > max_output_bytes:
                            output_limited_event.set()
            except (OSError, ValueError):
                return

        def write_stdin(stream: Any) -> None:
            try:
                stream.write(request_envelope)
                stream.flush()
            except (BrokenPipeError, OSError, ValueError) as error:
                stdin_writer_errors.append(error)
            finally:
                try:
                    stream.close()
                except (BrokenPipeError, OSError, ValueError) as error:
                    stdin_writer_errors.append(error)
                stdin_writer_done.set()

        if process is not None:
            assert process.stdout is not None
            assert process.stderr is not None
            for name, stream, target in (
                ("stdout", process.stdout, stdout_buffer),
                ("stderr", process.stderr, stderr_buffer),
            ):
                thread = threading.Thread(
                    target=read_stream,
                    args=(name, stream, target),
                    daemon=True,
                )
                thread.start()
                reader_threads.append(thread)

            tree_terminated = False
            if time.monotonic() >= deadline:
                timed_out = True
                stop_windows_tracker()
                terminate_process_tree(process, windows_job)
                tree_terminated = True
            else:
                assert process.stdin is not None
                stdin_writer_thread = threading.Thread(
                    target=write_stdin,
                    args=(process.stdin,),
                    daemon=True,
                )
                stdin_writer_thread.start()

                while process.poll() is None:
                    if windows_tracker_errors:
                        process_error = "process_tracking"
                        stop_windows_tracker()
                        terminate_process_tree(process, windows_job)
                        tree_terminated = True
                        break
                    if output_limited_event.is_set():
                        stop_windows_tracker()
                        terminate_process_tree(process, windows_job)
                        tree_terminated = True
                        break
                    if time.monotonic() >= deadline:
                        timed_out = True
                        stop_windows_tracker()
                        terminate_process_tree(process, windows_job)
                        tree_terminated = True
                        break
                    if stdin_writer_done.is_set() and stdin_writer_errors:
                        process_error = "stdin_write"
                        stop_windows_tracker()
                        terminate_process_tree(process, windows_job)
                        tree_terminated = True
                        break
                    time.sleep(0.01)
            if not tree_terminated and time.monotonic() >= deadline:
                timed_out = True
            if not tree_terminated:
                # Normal completion is not permission for a contained child or
                # process-group member to retain stdout/stderr pipes.
                stop_windows_tracker()
                terminate_process_tree(process, windows_job)
            try:
                process.wait(timeout=1)
            except subprocess.TimeoutExpired:
                terminate_process_tree(process, windows_job)
            if stdin_writer_thread is not None:
                stdin_writer_thread.join(timeout=1)
                if stdin_writer_thread.is_alive():
                    raw_stdin = getattr(process.stdin, "raw", None)
                    if raw_stdin is not None:
                        try:
                            raw_stdin.close()
                        except (OSError, ValueError):
                            pass
                    stdin_writer_thread.join(timeout=1)
                if stdin_writer_thread.is_alive():
                    process_error = process_error or "stdin_cleanup"
                elif stdin_writer_errors and process_error is None:
                    process_error = "stdin_write"
            for thread in reader_threads:
                thread.join(timeout=1)
            closeable_streams = [process.stdout, process.stderr]
            if (
                stdin_writer_thread is None
                or not stdin_writer_thread.is_alive()
            ):
                closeable_streams.append(process.stdin)
            for stream in closeable_streams:
                if stream is not None and not stream.closed:
                    try:
                        stream.close()
                    except OSError:
                        pass
            if os.name == "nt":
                process_handle = getattr(process, "_handle", None)
                if process_handle is not None:
                    process_handle.Close()
            process_exit_code = process.returncode
            process = None
            windows_job = None

        after, after_overflow = snapshot_workspace(cwd)
        changed_paths = sorted(
            path
            for path in set(before) | set(after)
            if before.get(path) != after.get(path)
        )
        workspace_overflow = before_overflow or after_overflow
        workspace = {
            "mutated": bool(changed_paths) or workspace_overflow,
            "changed_count": len(changed_paths),
            "path_digests": [
                sha256_text(path) for path in changed_paths[:MAX_REPORTED_PATHS]
            ],
            "scan_overflow": workspace_overflow,
        }

    output_limited = output_limited_event.is_set()
    process_record = {
        "exit_code": process_exit_code,
        "timed_out": timed_out,
        "output_limited": output_limited,
        "stdout_bytes": observed["stdout"],
        "stderr_bytes": observed["stderr"],
        "stdout_sha256": sha256_bytes(bytes(stdout_buffer)),
        "stderr_sha256": sha256_bytes(bytes(stderr_buffer)),
    }
    if timed_out:
        process_error = "timeout"
    elif output_limited:
        process_error = "output_limit"
    elif (
        process_error is None
        and process_exit_code is not None
        and process_exit_code != 0
    ):
        process_error = "process_exit"
    return (
        process_record,
        bytes(stdout_buffer),
        bytes(stderr_buffer),
        workspace,
        process_error,
    )


def score_decision(
    actual: dict[str, Any],
    expected: dict[str, Any],
    catalog: dict[str, Any],
    manifest: dict[str, Any],
) -> tuple[float, str, list[str], bool]:
    penalties = catalog["scoring"]["penalties"]
    score = 100.0
    failure_classes: set[str] = set()
    mandatory_failure = False
    critical_failure = False

    if actual["mode"] != expected["mode"]:
        score -= float(penalties["wrong_mode"])
        failure_classes.add("wrong_mode")
        mandatory_failure = True

    actual_signals = set(actual["signals"])
    expected_signals = set(expected["signals"])
    missing_signals = expected_signals - actual_signals
    unnecessary_signals = actual_signals - expected_signals
    if missing_signals:
        score -= len(missing_signals) * float(penalties["missing_signal"])
        failure_classes.add("missing_signal")
        mandatory_failure = True
    if unnecessary_signals:
        score -= len(unnecessary_signals) * float(penalties["unnecessary_signal"])
        failure_classes.add("unnecessary_signal")

    risk_rank = {
        value: index for index, value in enumerate(manifest["risk_order"])
    }
    expected_risk_rank = risk_rank[expected["risk"]]
    actual_risk_rank = risk_rank[actual["risk"]]
    if actual_risk_rank < expected_risk_rank:
        score -= (expected_risk_rank - actual_risk_rank) * float(
            penalties["risk_underroute_per_level"]
        )
        failure_classes.add("risk_underroute")
    elif actual_risk_rank > expected_risk_rank:
        score -= (actual_risk_rank - expected_risk_rank) * float(
            penalties["risk_overroute_per_level"]
        )
        failure_classes.add("risk_overroute")

    confirmation_rank = {
        value: index for index, value in enumerate(manifest["confirmation_order"])
    }
    expected_confirmation_rank = confirmation_rank[expected["confirmation"]]
    actual_confirmation_rank = confirmation_rank[actual["confirmation"]]
    if actual_confirmation_rank < expected_confirmation_rank:
        score -= (expected_confirmation_rank - actual_confirmation_rank) * float(
            penalties["confirmation_underroute_per_level"]
        )
        failure_classes.add("confirmation_underroute")
    elif actual_confirmation_rank > expected_confirmation_rank:
        score -= (actual_confirmation_rank - expected_confirmation_rank) * float(
            penalties["confirmation_overroute_per_level"]
        )
        failure_classes.add("confirmation_overroute")

    if actual["lead_skill"] != expected["lead_skill"]:
        score -= float(penalties["wrong_lead_skill"])
        failure_classes.add("wrong_lead_skill")

    actual_supports = set(actual["supporting_skills"])
    expected_supports = set(expected["supporting_skills"])
    missing_supports = expected_supports - actual_supports
    unnecessary_supports = actual_supports - expected_supports
    if missing_supports:
        score -= len(missing_supports) * float(
            penalties["missing_supporting_skill"]
        )
        failure_classes.add("missing_supporting_skill")
    if unnecessary_supports:
        score -= len(unnecessary_supports) * float(
            penalties["unnecessary_supporting_skill"]
        )
        failure_classes.add("unnecessary_supporting_skill")

    missing_critical_signals = [
        signal_name
        for signal_name in missing_signals
        if (
            manifest["routing_signals"][signal_name]["minimum_risk"] == "critical"
            or manifest["routing_signals"][signal_name]["confirmation"]
            == "fresh_confirmation"
        )
    ]
    if (
        expected["risk"] == "critical"
        and actual_risk_rank < expected_risk_rank
    ):
        critical_failure = True
    if (
        expected["confirmation"] == "fresh_confirmation"
        and actual_confirmation_rank < expected_confirmation_rank
    ):
        critical_failure = True
    if missing_critical_signals:
        critical_failure = True
    if expected["mode"] == "operate" and actual["mode"] != "operate":
        critical_failure = True
    if critical_failure:
        score -= float(penalties["critical_underroute"])
        failure_classes.add("critical_failure")

    unrounded_score = max(0.0, score)
    status = (
        "PASS"
        if (
            not mandatory_failure
            and not critical_failure
            and unrounded_score >= float(catalog["scoring"]["pass_score"])
        )
        else "FAIL"
    )
    reported_score = round(unrounded_score, 2)
    return reported_score, status, sorted(failure_classes), critical_failure


def combine_statuses(statuses: list[str]) -> str:
    return max(statuses, key=lambda status: STATUS_ORDER[status])


def private_case_ref(secret: bytes, case_id: str) -> str:
    digest = hmac.new(
        secret,
        b"routing-case-ref\0" + case_id.encode("utf-8"),
        hashlib.sha256,
    ).hexdigest()
    return f"private-{digest}"


def run_trial(
    adapter: dict[str, Any],
    case: dict[str, Any],
    trial_number: int,
    catalog: dict[str, Any],
    manifest: dict[str, Any],
    visibility: str,
    timeout_seconds: float,
    max_output_bytes: int,
) -> dict[str, Any]:
    started_at = utc_now()
    (
        process_record,
        stdout_content,
        _stderr_content,
        workspace,
        process_error,
    ) = execute_adapter(
        adapter,
        case["request_envelope"],
        timeout_seconds,
        max_output_bytes,
    )
    failure_classes: list[str] = []
    decision: dict[str, Any] | None = None
    score: float | None = None

    if process_error is not None:
        status = "ERROR"
        failure_classes.append(process_error)
    else:
        try:
            stdout_text = stdout_content.decode("utf-8")
            parsed = parse_json(stdout_text, "adapter stdout")
        except (UnicodeDecodeError, ConfigurationError):
            status = "INVALID"
            failure_classes.append("invalid_json_output")
        else:
            decision, validation_failures = validate_decision(parsed, manifest)
            if decision is None:
                status = "INVALID"
                failure_classes.extend(validation_failures)
            else:
                (
                    measured_score,
                    status,
                    scoring_failures,
                    _critical_failure,
                ) = score_decision(
                    decision,
                    case["expected"],
                    catalog,
                    manifest,
                )
                failure_classes.extend(scoring_failures)
                if visibility == "public":
                    score = measured_score

    if workspace["mutated"]:
        failure_classes.append("workspace_mutation")
        if status == "PASS":
            status = "FAIL"

    return {
        "trial": trial_number,
        "started_at": started_at,
        "duration_seconds": 0.0,
        "status": status,
        "decision": decision,
        "score": score,
        "failure_classes": sorted(set(failure_classes)),
        "workspace": workspace,
        "process": process_record,
    }


def adapter_summary(case_results: list[dict[str, Any]]) -> dict[str, Any]:
    trials = [
        trial
        for case_result in case_results
        for trial in case_result["trials"]
    ]
    counts = {
        status: sum(1 for trial in trials if trial["status"] == status)
        for status in STATUS_ORDER
    }
    total = len(trials)
    return {
        "total_trials": total,
        "pass": counts["PASS"],
        "fail": counts["FAIL"],
        "invalid": counts["INVALID"],
        "error": counts["ERROR"],
        "pass_rate": round(counts["PASS"] / total, 6) if total else 0.0,
        "workspace_mutation_trials": sum(
            1 for trial in trials if trial["workspace"]["mutated"]
        ),
        "critical_failure_trials": sum(
            1
            for trial in trials
            if "critical_failure" in trial["failure_classes"]
        ),
    }


def build_argument_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Run provider-neutral routing model evaluations.",
    )
    parser.add_argument(
        "--root",
        type=Path,
        default=Path(__file__).resolve().parent.parent,
    )
    catalog_group = parser.add_mutually_exclusive_group(required=True)
    catalog_group.add_argument("--public-catalog", type=Path)
    catalog_group.add_argument("--private-catalog", type=Path)
    parser.add_argument("--variants", type=Path)
    parser.add_argument(
        "--adapter",
        type=Path,
        action="append",
        required=True,
    )
    parser.add_argument("--case", action="append", default=[])
    parser.add_argument("--trials", type=int, required=True)
    parser.add_argument("--timeout-seconds", type=float, required=True)
    parser.add_argument("--max-request-bytes", type=int, required=True)
    parser.add_argument("--max-output-bytes", type=int, required=True)
    parser.add_argument("--max-invocations", type=int, required=True)
    parser.add_argument("--output", type=Path, required=True)
    return parser


def main() -> int:
    parser = build_argument_parser()
    args = parser.parse_args()
    try:
        if args.trials < 1:
            raise ConfigurationError("--trials must be at least 1")
        if not is_number(args.timeout_seconds) or args.timeout_seconds <= 0:
            raise ConfigurationError("--timeout-seconds must be greater than zero")
        if args.max_request_bytes < 1:
            raise ConfigurationError("--max-request-bytes must be at least 1")
        if args.max_output_bytes < 1:
            raise ConfigurationError("--max-output-bytes must be at least 1")
        if args.max_invocations < 1:
            raise ConfigurationError("--max-invocations must be at least 1")

        root = args.root.resolve()
        output_path = args.output.resolve()
        if output_path.exists():
            raise ConfigurationError("--output must not already exist")
        manifest = load_manifest(root)

        if args.private_catalog is not None:
            catalog_path = args.private_catalog.resolve()
            visibility = "private"
        else:
            catalog_path = args.public_catalog.resolve()
            visibility = "public"
        catalog_document, catalog_content = load_json(
            catalog_path,
            "routing catalog",
        )
        validate_document_schema(
            catalog_document,
            root / "schemas" / "routing-evaluations.schema.json",
            "routing catalog",
        )
        catalog, base_cases, inline_variants = validate_catalog(
            catalog_document,
            manifest,
        )
        external_variants, variants_digest = load_variants(
            None if args.variants is None else args.variants.resolve(),
            base_cases,
            inline_variants,
        )
        all_cases = base_cases + inline_variants + external_variants
        enforce_total_case_limit(all_cases, catalog)
        if args.case:
            selected_ids = set(args.case)
            known_ids = {case["id"] for case in all_cases}
            if not selected_ids.issubset(known_ids):
                raise ConfigurationError("--case references an unknown case")
            selected_cases = [
                case for case in all_cases if case["id"] in selected_ids
            ]
        else:
            selected_cases = all_cases
        if not selected_cases:
            raise ConfigurationError("no routing cases were selected")
        selection_scope = (
            "full" if len(selected_cases) == len(all_cases) else "partial"
        )
        for case in selected_cases:
            case["request_envelope"] = serialize_request_envelope(
                case["request"],
                int(args.max_request_bytes),
            )

        adapters: list[dict[str, Any]] = []
        adapter_ids: set[str] = set()
        for adapter_path in args.adapter:
            adapter_document, adapter_content = load_json(
                adapter_path.resolve(),
                "adapter configuration",
            )
            validate_document_schema(
                adapter_document,
                root / "schemas" / "routing-model-adapter.schema.json",
                "adapter configuration",
            )
            adapter = validate_adapter(
                adapter_document,
                adapter_content,
                dict(os.environ),
            )
            if adapter["id"] in adapter_ids:
                raise ConfigurationError("adapter ids must be unique")
            adapter_ids.add(adapter["id"])
            adapters.append(adapter)

        planned_invocations = (
            len(selected_cases) * len(adapters) * int(args.trials)
        )
        if planned_invocations > int(args.max_invocations):
            raise ConfigurationError(
                "planned routing model invocations exceed "
                f"--max-invocations {args.max_invocations}; "
                f"planned {planned_invocations}"
            )

        catalog_digest = sha256_bytes(catalog_content)
        private_reference_secret = (
            secrets.token_bytes(32) if visibility == "private" else None
        )
        adapter_results: list[dict[str, Any]] = []
        for adapter in adapters:
            case_results: list[dict[str, Any]] = []
            for case in selected_cases:
                case_ref = (
                    case["id"]
                    if visibility == "public"
                    else private_case_ref(
                        private_reference_secret,
                        case["id"],
                    )
                )
                variant_of = case["variant_of"]
                variant_ref = (
                    None
                    if variant_of is None
                    else (
                        variant_of
                        if visibility == "public"
                        else private_case_ref(
                            private_reference_secret,
                            variant_of,
                        )
                    )
                )
                trial_results: list[dict[str, Any]] = []
                for trial_number in range(1, args.trials + 1):
                    trial_started = time.monotonic()
                    trial_result = run_trial(
                        adapter,
                        case,
                        trial_number,
                        catalog,
                        manifest,
                        visibility,
                        float(args.timeout_seconds),
                        int(args.max_output_bytes),
                    )
                    trial_result["duration_seconds"] = round(
                        max(0.0, time.monotonic() - trial_started),
                        6,
                    )
                    trial_results.append(trial_result)
                case_results.append(
                    {
                        "case_ref": case_ref,
                        "variant_of": variant_ref,
                        "trials": trial_results,
                    }
                )
            summary = adapter_summary(case_results)
            adapter_status = combine_statuses(
                [
                    trial["status"]
                    for case_result in case_results
                    for trial in case_result["trials"]
                ]
            )
            adapter_results.append(
                {
                    "id": adapter["id"],
                    "config_sha256": adapter["config_sha256"],
                    "model": adapter["model"],
                    "instruction_binding": adapter["instruction_binding"],
                    "summary": summary,
                    "cases": case_results,
                    "status": adapter_status,
                }
            )

        underlying_report_status = combine_statuses(
            [adapter_result["status"] for adapter_result in adapter_results]
        )
        report_status = (
            "PARTIAL"
            if (
                selection_scope == "partial"
                and underlying_report_status == "PASS"
            )
            else underlying_report_status
        )
        instruction_bindings = {
            adapter_result["instruction_binding"]
            for adapter_result in adapter_results
        }
        status_by_adapter = {
            adapter_result["id"]: adapter_result["status"]
            for adapter_result in adapter_results
        }
        report = {
            "$schema": REPORT_SCHEMA,
            "schema_version": 1,
            "rules_pack_version": manifest["pack_version"],
            "generated_at": utc_now(),
            "catalog": {
                "visibility": visibility,
                "sha256": catalog_digest,
                "variants_sha256": variants_digest,
                "base_case_count": len(base_cases),
                "variant_count": len(inline_variants) + len(external_variants),
            },
            "execution": {
                "trials": args.trials,
                "timeout_seconds": float(args.timeout_seconds),
                "max_request_bytes": args.max_request_bytes,
                "max_output_bytes": args.max_output_bytes,
                "max_invocations": args.max_invocations,
                "planned_invocations": planned_invocations,
                "selection_scope": selection_scope,
                "selected_case_count": len(selected_cases),
                "workspace_observation_scope": "disposable_cwd_only",
                "process_containment": (
                    "windows_job_plus_observed_descendants"
                    if os.name == "nt"
                    else "posix_process_group"
                ),
            },
            "adapters": adapter_results,
            "comparison": {
                "adapter_count": len(adapter_results),
                "shared_case_count": len(selected_cases),
                "comparable": (
                    len(adapter_results) > 1 and len(instruction_bindings) == 1
                ),
                "all_adapters_pass": all(
                    result["status"] == "PASS" for result in adapter_results
                ),
                "status_by_adapter": status_by_adapter,
            },
            "status": report_status,
        }

        output_path.parent.mkdir(parents=True, exist_ok=True)
        with output_path.open("w", encoding="utf-8", newline="\n") as output_file:
            json.dump(report, output_file, indent=2, ensure_ascii=False)
            output_file.write("\n")

        print(
            "Routing model evaluation "
            f"{report_status}: {len(adapter_results)} adapter(s), "
            f"{len(selected_cases)} case(s), {args.trials} trial(s)."
        )
        if report_status == "PASS":
            return 0
        if report_status == "FAIL":
            return 1
        if report_status == "PARTIAL":
            return 4
        return 2
    except ConfigurationError as error:
        print(f"Routing model evaluation INVALID: {error}", file=sys.stderr)
        return 2
    except Exception as error:  # fail closed without exposing adapter output
        print(
            f"Routing model evaluation ERROR: {type(error).__name__}",
            file=sys.stderr,
        )
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
