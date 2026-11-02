"""episode audio links

Revision ID: 0009
Revises: 0008
Create Date: 2026-11-04 12:00:00.000000
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op


revision: str = '0009'
down_revision: str | None = '0008'
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    with op.batch_alter_table('items', schema=None) as batch_op:
        batch_op.add_column(sa.Column('audio_url', sa.Text(), nullable=True))
        batch_op.add_column(sa.Column('duration_s', sa.Integer(), nullable=True))


def downgrade() -> None:
    with op.batch_alter_table('items', schema=None) as batch_op:
        batch_op.drop_column('duration_s')
        batch_op.drop_column('audio_url')
