from sqlalchemy import inspect, text
from sqlalchemy.engine import Engine


def ensure_runtime_schema_compat(engine: Engine) -> None:
    inspector = inspect(engine)
    table_names = set(inspector.get_table_names())
    if "checkin_rules" not in table_names and "attendance_records" not in table_names:
        return

    statements: list[str] = []

    if "checkin_rules" in table_names:
        existing_columns = {column["name"] for column in inspector.get_columns("checkin_rules")}
        if "location_name" not in existing_columns:
            statements.append("ALTER TABLE checkin_rules ADD COLUMN location_name VARCHAR(255)")
        if "location_address" not in existing_columns:
            statements.append("ALTER TABLE checkin_rules ADD COLUMN location_address VARCHAR(500)")

    if "attendance_records" in table_names:
        statements.extend(
            [
                "CREATE INDEX IF NOT EXISTS idx_attendance_records_record_date ON attendance_records(record_date)",
                "CREATE INDEX IF NOT EXISTS idx_attendance_records_record_date_type ON attendance_records(record_date, record_type)",
                "CREATE INDEX IF NOT EXISTS idx_attendance_records_user_date_type ON attendance_records(user_id, record_date, record_type)",
            ]
        )

    if not statements:
        return

    with engine.begin() as connection:
        for statement in statements:
            connection.execute(text(statement))
