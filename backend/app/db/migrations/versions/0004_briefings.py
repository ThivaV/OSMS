"""morning briefings

Revision ID: 0004
Revises: 0003
Create Date: 2026-10-31 14:30:00.000000
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op


revision: str = '0004'
down_revision: str | None = '0003'
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table('briefings',
    sa.Column('id', sa.Integer(), nullable=False),
    sa.Column('user_id', sa.String(length=64), nullable=True),
    sa.Column('language', sa.String(length=8), nullable=False),
    sa.Column('intro', sa.Text(), nullable=False),
    sa.Column('chapters', sa.JSON(), nullable=False),
    sa.Column('audio_path', sa.String(length=200), nullable=True),
    sa.Column('duration_ms', sa.Integer(), nullable=False),
    sa.Column('model', sa.String(length=64), nullable=False),
    sa.Column('prompt_version', sa.String(length=32), nullable=False),
    sa.Column('created_at', sa.DateTime(timezone=True), nullable=False),
    sa.ForeignKeyConstraint(['user_id'], ['users.id'], ondelete='CASCADE'),
    sa.PrimaryKeyConstraint('id')
    )
    with op.batch_alter_table('briefings', schema=None) as batch_op:
        batch_op.create_index(batch_op.f('ix_briefings_user_id'), ['user_id'], unique=False)
        batch_op.create_index(batch_op.f('ix_briefings_created_at'), ['created_at'], unique=False)


def downgrade() -> None:
    with op.batch_alter_table('briefings', schema=None) as batch_op:
        batch_op.drop_index(batch_op.f('ix_briefings_created_at'))
        batch_op.drop_index(batch_op.f('ix_briefings_user_id'))
    op.drop_table('briefings')
