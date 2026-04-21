# =============================================================================
# dagster_orchestration/jobs/definitions.py
#
# Purpose:
#   Defines the Dagster job, ops, schedule, and Definitions object that wire
#   together the ingestion pipeline and dbt transformations into a single
#   daily-scheduled workflow.
#
# Why we need it:
#   Without an orchestrator, ingestion and dbt would have to be triggered
#   manually and in the right order.  Dagster ensures that dbt only runs after
#   ingestion succeeds, provides a visual UI for monitoring runs, emits alerts
#   on failure, and lets you back-fill or re-run specific steps in isolation.
#
# Reproducibility – variables that MAY need changing:
#   cron_schedule      -> "0 2 * * *"  = 02:00 every day; adjust to your timezone
#   execution_timezone -> "Europe/Madrid"; change to your local timezone
#   PROJECT_ROOT env   -> override if the project root is not two levels above
#                         this file (e.g. inside a custom Docker layout)
# =============================================================================

import os
import subprocess
from pathlib import Path

from dagster import Definitions, ScheduleDefinition, job, op


def _project_root() -> Path:
    """Resolve the repository root directory.

    Reads the PROJECT_ROOT environment variable first so that Docker or CI
    environments can override the default heuristic (two directories above
    this file).
    """
    root = os.getenv("PROJECT_ROOT")
    if root:
        return Path(root)
    return Path(__file__).resolve().parents[2]


def _run_command(cmd: list[str], cwd: Path) -> None:
    """Run *cmd* as a subprocess in *cwd*, raising RuntimeError on failure.

    Using check=False and inspecting returncode manually lets us surface a
    cleaner error message in the Dagster UI instead of a raw CalledProcessError.
    """
    completed = subprocess.run(cmd, cwd=str(cwd), check=False, text=True)
    if completed.returncode != 0:
        raise RuntimeError(f"Command failed: {' '.join(cmd)}")


@op
def run_ingestion() -> None:
    """Dagster op: execute the dlt ingestion pipeline.

    Runs `python -m ingestion.pipeline.run` from the project root so that all
    environment variables (GCP_PROJECT_ID, Kaggle credentials, etc.) set in
    the process or .env file are inherited automatically.
    """
    root = _project_root()
    _run_command(["python", "-m", "ingestion.pipeline.run"], cwd=root)


@op
def run_dbt_build() -> None:
    """Dagster op: install dbt packages then build all dbt models and tests.

    `dbt deps` is run first on every execution to ensure packages declared in
    packages.yml are present even in a fresh container.  `dbt build` runs
    models, seeds, snapshots, and tests in dependency order.
    """
    root = _project_root()
    transform_dir = root / "transform"
    _run_command(["dbt", "deps", "--profiles-dir", "."], cwd=transform_dir)
    _run_command(["dbt", "build", "--profiles-dir", "."], cwd=transform_dir)


@job
def daily_olist_pipeline() -> None:
    """Full ELT job: ingestion → dbt build (run in sequence).

    Dagster automatically passes the output token of run_ingestion into
    run_dbt_build, guaranteeing that dbt only executes when ingestion succeeds.
    """
    run_dbt_build(run_ingestion())


# CHANGE THIS: adjust cron and timezone to match when you want the pipeline to run.
# Current setting: 02:00 AM Madrid time (UTC+1/UTC+2 depending on DST).
daily_schedule = ScheduleDefinition(
    job=daily_olist_pipeline,
    cron_schedule="0 2 * * *",
    execution_timezone="Europe/Madrid",
)


# defs is the top-level Dagster Definitions object loaded by `dagster dev` and
# the dagster-daemon service.  Add sensors, resources, or assets here as the
# project grows.
defs = Definitions(
    jobs=[daily_olist_pipeline],
    schedules=[daily_schedule],
)
