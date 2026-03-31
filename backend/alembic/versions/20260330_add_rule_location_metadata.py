"""add rule location metadata

Revision ID: 20260330_add_rule_location_metadata
Revises:
Create Date: 2026-03-30
"""

from alembic import op
import sqlalchemy as sa


revision = "20260330_add_rule_location_metadata"
down_revision = None
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("checkin_rules", sa.Column("location_name", sa.String(length=255), nullable=True))
    op.add_column("checkin_rules", sa.Column("location_address", sa.String(length=500), nullable=True))


def downgrade() -> None:
    op.drop_column("checkin_rules", "location_address")
    op.drop_column("checkin_rules", "location_name")
