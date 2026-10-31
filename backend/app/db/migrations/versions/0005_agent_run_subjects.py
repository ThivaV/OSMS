"""what each agent run decided about

Revision ID: 0005
Revises: 0004
Create Date: 2026-10-31 15:30:00.000000
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op


revision: str = '0005'
down_revision: str | None = '0004'
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    with op.batch_alter_table('agent_runs', schema=None) as batch_op:
        batch_op.add_column(sa.Column('subject', sa.String(length=64), nullable=True))
        batch_op.create_index(batch_op.f('ix_agent_runs_subject'), ['subject'], unique=False)


def downgrade() -> None:
    with op.batch_alter_table('agent_runs', schema=None) as batch_op:
        batch_op.drop_index(batch_op.f('ix_agent_runs_subject'))
        batch_op.drop_column('subject')
