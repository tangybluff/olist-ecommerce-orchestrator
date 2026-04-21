import os
import subprocess
from pathlib import Path

from dagster import Definitions, ScheduleDefinition, job, op


def _project_root() -> Path:
    root = os.getenv("PROJECT_ROOT")
    if root:
        return Path(root)
    return Path(__file__).resolve().parents[2]


def _run_command(cmd: list[str], cwd: Path) -> None:
    completed = subprocess.run(cmd, cwd=str(cwd), check=False, text=True)
    if completed.returncode != 0:
        raise RuntimeError(f"Command failed: {' '.join(cmd)}")


@op
def run_ingestion() -> None:
    root = _project_root()
    _run_command(["python", "-m", "ingestion.pipeline.run"], cwd=root)


@op
def run_dbt_build() -> None:
    root = _project_root()
    transform_dir = root / "transform"
    _run_command(["dbt", "deps", "--profiles-dir", "."], cwd=transform_dir)
    _run_command(["dbt", "build", "--profiles-dir", "."], cwd=transform_dir)


@job
def daily_olist_pipeline() -> None:
    run_dbt_build(run_ingestion())


daily_schedule = ScheduleDefinition(
    job=daily_olist_pipeline,
    cron_schedule="0 2 * * *",
    execution_timezone="Europe/Madrid",
)


defs = Definitions(
    jobs=[daily_olist_pipeline],
    schedules=[daily_schedule],
)
