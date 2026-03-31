from sqlalchemy import inspect, text
from sqlalchemy.engine import Engine


def ensure_runtime_schema_compat(engine: Engine) -> None:
    inspector = inspect(engine)
    if "checkin_rules" not in set(inspector.get_table_names()):
        return

    existing_columns = {column["name"] for column in inspector.get_columns("checkin_rules")}
    statements: list[str] = []
    if "location_name" not in existing_columns:
        statements.append("ALTER TABLE checkin_rules ADD COLUMN location_name VARCHAR(255)")
    if "location_address" not in existing_columns:
        statements.append("ALTER TABLE checkin_rules ADD COLUMN location_address VARCHAR(500)")

    if not statements:
        return

    with engine.begin() as connection:
        for statement in statements:
            connection.execute(text(statement))
