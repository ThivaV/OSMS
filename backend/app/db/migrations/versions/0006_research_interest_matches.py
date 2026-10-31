"""arXiv queries for research interests, and the papers they matched

Revision ID: 0006
Revises: 0005
Create Date: 2026-10-31 16:30:00.000000
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op


revision: str = '0006'
down_revision: str | None = '0005'
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    with op.batch_alter_table('interests', schema=None) as batch_op:
        batch_op.add_column(sa.Column('query_url', sa.String(length=2000), nullable=True))
        batch_op.create_index(batch_op.f('ix_interests_query_url'), ['query_url'], unique=False)
    op.create_table('interest_matches',
    sa.Column('id', sa.Integer(), nullable=False),
    sa.Column('user_id', sa.String(length=64), nullable=False),
    sa.Column('interest_id', sa.Integer(), nullable=False),
    sa.Column('item_id', sa.Integer(), nullable=False),
    sa.Column('matched_terms', sa.JSON(), nullable=False),
    sa.Column('created_at', sa.DateTime(timezone=True), nullable=False),
    sa.ForeignKeyConstraint(['interest_id'], ['interests.id'], ondelete='CASCADE'),
    sa.ForeignKeyConstraint(['item_id'], ['items.id'], ondelete='CASCADE'),
    sa.ForeignKeyConstraint(['user_id'], ['users.id'], ondelete='CASCADE'),
    sa.PrimaryKeyConstraint('id'),
    sa.UniqueConstraint('interest_id', 'item_id')
    )
    with op.batch_alter_table('interest_matches', schema=None) as batch_op:
        batch_op.create_index(batch_op.f('ix_interest_matches_user_id'), ['user_id'], unique=False)
        batch_op.create_index(batch_op.f('ix_interest_matches_interest_id'), ['interest_id'], unique=False)
        batch_op.create_index(batch_op.f('ix_interest_matches_item_id'), ['item_id'], unique=False)
        batch_op.create_index(batch_op.f('ix_interest_matches_created_at'), ['created_at'], unique=False)


def downgrade() -> None:
    op.drop_table('interest_matches')
    with op.batch_alter_table('interests', schema=None) as batch_op:
        batch_op.drop_index(batch_op.f('ix_interests_query_url'))
        batch_op.drop_column('query_url')
