"""
Cotton Guard - Authoritative Service State Machine & Model Lifecycle Manager.

Manages the 5 core operational states of the AI inference engine:
- STOPPED: Model is unloaded from RAM; public prediction requests rejected with HTTP 503.
- STARTING: Model session is loading into RAM and running verification warmup.
- RUNNING: Model session active; full multi-stage quality/foliage/disease inference operational.
- STOPPING: Draining active requests; releasing ONNX session memory via garbage collection.
- ERROR: An exception occurred during model load/inference lifecycle.
"""

import os
import gc
import time
import asyncio
from enum import Enum
from datetime import datetime, timezone
from typing import Optional, Dict, Any, Callable

class ServiceState(str, Enum):
    STOPPED = "STOPPED"
    STARTING = "STARTING"
    RUNNING = "RUNNING"
    STOPPING = "STOPPING"
    ERROR = "ERROR"

class ServiceStateManager:
    def __init__(self, initial_state: ServiceState = ServiceState.RUNNING):
        self._state: ServiceState = initial_state
        self._error_message: Optional[str] = None
        self._last_state_change: float = time.time()
        self._started_at: Optional[float] = time.time() if initial_state == ServiceState.RUNNING else None
        self._lock = asyncio.Lock()
        self._load_callback: Optional[Callable[[], bool]] = None
        self._unload_callback: Optional[Callable[[], None]] = None
        self._prediction_count: int = 0

    def configure_callbacks(
        self,
        load_fn: Callable[[], bool],
        unload_fn: Callable[[], None]
    ):
        """Wires model loading and unloading routines from main.py."""
        self._load_callback = load_fn
        self._unload_callback = unload_fn

    @property
    def state(self) -> ServiceState:
        return self._state

    @property
    def status_label(self) -> str:
        return self._state.value

    @property
    def is_running(self) -> bool:
        return self._state == ServiceState.RUNNING

    @property
    def error_message(self) -> Optional[str]:
        return self._error_message

    def increment_predictions(self):
        self._prediction_count += 1

    def get_status_summary(self) -> Dict[str, Any]:
        uptime = 0.0
        if self._state == ServiceState.RUNNING and self._started_at:
            uptime = round(time.time() - self._started_at, 2)

        return {
            "state": self._state.value,
            "is_running": self.is_running,
            "uptime_seconds": uptime,
            "last_state_change": datetime.fromtimestamp(self._last_state_change, tz=timezone.utc).isoformat(),
            "predictions_served": self._prediction_count,
            "error_message": self._error_message
        }

    async def start_service(self, admin_email: str, ip_address: str = "") -> Dict[str, Any]:
        """
        Transitions service from STOPPED/ERROR to RUNNING.
        Thread-safe and debounced via asyncio.Lock.
        """
        async with self._lock:
            if self._state == ServiceState.RUNNING:
                return {
                    "success": True,
                    "state": self._state.value,
                    "message": "AI Inference Service is already running."
                }

            if self._state in (ServiceState.STARTING, ServiceState.STOPPING):
                return {
                    "success": False,
                    "state": self._state.value,
                    "message": f"Service is currently in transition ({self._state.value}). Please wait."
                }

            prior = self._state
            self._state = ServiceState.STARTING
            self._last_state_change = time.time()
            self._error_message = None

            try:
                # Load ONNX model via wired callback
                loaded = False
                if self._load_callback:
                    loaded = self._load_callback()

                if loaded:
                    self._state = ServiceState.RUNNING
                    self._started_at = time.time()
                    self._last_state_change = time.time()
                    return {
                        "success": True,
                        "prior_state": prior.value,
                        "state": self._state.value,
                        "message": "AI Inference Service started successfully. Model loaded into RAM."
                    }
                else:
                    self._state = ServiceState.ERROR
                    self._error_message = "Failed to load ONNX model. Check model file integrity."
                    self._last_state_change = time.time()
                    return {
                        "success": False,
                        "prior_state": prior.value,
                        "state": self._state.value,
                        "message": self._error_message
                    }
            except Exception as e:
                self._state = ServiceState.ERROR
                self._error_message = f"Exception during service start: {str(e)}"
                self._last_state_change = time.time()
                return {
                    "success": False,
                    "prior_state": prior.value,
                    "state": self._state.value,
                    "message": self._error_message
                }

    async def stop_service(self, admin_email: str, ip_address: str = "") -> Dict[str, Any]:
        """
        Transitions service from RUNNING to STOPPED.
        Safely unloads the ONNX model from RAM.
        """
        async with self._lock:
            if self._state == ServiceState.STOPPED:
                return {
                    "success": True,
                    "state": self._state.value,
                    "message": "AI Inference Service is already stopped."
                }

            if self._state in (ServiceState.STARTING, ServiceState.STOPPING):
                return {
                    "success": False,
                    "state": self._state.value,
                    "message": f"Service is currently in transition ({self._state.value}). Please wait."
                }

            prior = self._state
            self._state = ServiceState.STOPPING
            self._last_state_change = time.time()

            try:
                # Unload ONNX model via wired callback
                if self._unload_callback:
                    self._unload_callback()

                # Trigger Python GC to release memory back to OS
                gc.collect()

                self._state = ServiceState.STOPPED
                self._started_at = None
                self._last_state_change = time.time()
                return {
                    "success": True,
                    "prior_state": prior.value,
                    "state": self._state.value,
                    "message": "AI Inference Service stopped successfully. Model unloaded from RAM."
                }
            except Exception as e:
                self._state = ServiceState.ERROR
                self._error_message = f"Exception during service stop: {str(e)}"
                self._last_state_change = time.time()
                return {
                    "success": False,
                    "prior_state": prior.value,
                    "state": self._state.value,
                    "message": self._error_message
                }

# Global singleton state manager
service_state = ServiceStateManager(
    initial_state=ServiceState.RUNNING if os.environ.get("INITIAL_SERVICE_STATE", "RUNNING").upper() == "RUNNING" else ServiceState.STOPPED
)
