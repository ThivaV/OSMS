"""items, jobs, stories and their history

Revision ID: 0003
Revises: 0002
Create Date: 2026-10-30 14:04:29.237561
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op


revision: str = '0003'
down_revision: str | None = '0002'
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table('jobs',
    sa.Column('id', sa.Integer(), nullable=False),
    sa.Column('kind', sa.String(length=32), nullable=False),
    sa.Column('ref', sa.String(length=64), nullable=False),
    sa.Column('status', sa.String(length=16), nullable=False),
    sa.Column('attempts', sa.Integer(), nullable=False),
    sa.Column('run_after', sa.DateTime(timezone=True), nullable=False),
    sa.Column('last_error', sa.Text(), nullable=True),
    sa.Column('created_at', sa.DateTime(timezone=True), nullable=False),
    sa.Column('updated_at', sa.DateTime(timezone=True), nullable=False),
    sa.PrimaryKeyConstraint('id')
    )
    with op.batch_alter_table('jobs', schema=None) as batch_op:
        batch_op.create_index(batch_op.f('ix_jobs_run_after'), ['run_after'], unique=False)
        batch_op.create_index(batch_op.f('ix_jobs_status'), ['status'], unique=False)

    op.create_table('stories',
    sa.Column('id', sa.Integer(), nullable=False),
    sa.Column('created_at', sa.DateTime(timezone=True), nullable=False),
    sa.Column('updated_at', sa.DateTime(timezone=True), nullable=False),
    sa.PrimaryKeyConstraint('id')
    )
    with op.batch_alter_table('stories', schema=None) as batch_op:
        batch_op.create_index(batch_op.f('ix_stories_updated_at'), ['updated_at'], unique=False)

    op.create_table('items',
    sa.Column('id', sa.Integer(), nullable=False),
    sa.Column('source_id', sa.Integer(), nullable=False),
    sa.Column('guid', sa.Text(), nullable=False),
    sa.Column('link', sa.Text(), nullable=True),
    sa.Column('title', sa.Text(), nullable=False),
    sa.Column('text', sa.Text(), nullable=False),
    sa.Column('language', sa.String(length=8), nullable=False),
    sa.Column('kind', sa.String(length=16), nullable=False),
    sa.Column('published_at', sa.DateTime(timezone=True), nullable=False),
    sa.Column('fetched_at', sa.DateTime(timezone=True), nullable=False),
    sa.Column('updated_at', sa.DateTime(timezone=True), nullable=False),
    sa.Column('content_hash', sa.String(length=64), nullable=False),
    sa.Column('status', sa.String(length=16), nullable=False),
    sa.Column('drop_reason', sa.Text(), nullable=True),
    sa.Column('names', sa.JSON(), nullable=False),
    sa.Column('vector_status', sa.String(length=16), nullable=False),
    sa.Column('story_id', sa.Integer(), nullable=True),
    sa.ForeignKeyConstraint(['source_id'], ['sources.id'], ondelete='CASCADE'),
    sa.ForeignKeyConstraint(['story_id'], ['stories.id'], ondelete='SET NULL'),
    sa.PrimaryKeyConstraint('id'),
    sa.UniqueConstraint('source_id', 'guid')
    )
    with op.batch_alter_table('items', schema=None) as batch_op:
        batch_op.create_index(batch_op.f('ix_items_published_at'), ['published_at'], unique=False)
        batch_op.create_index(batch_op.f('ix_items_source_id'), ['source_id'], unique=False)
        batch_op.create_index(batch_op.f('ix_items_story_id'), ['story_id'], unique=False)

    op.create_table('read_state',
    sa.Column('user_id', sa.String(length=64), nullable=False),
    sa.Column('story_id', sa.Integer(), nullable=False),
    sa.Column('read_at', sa.DateTime(timezone=True), nullable=False),
    sa.ForeignKeyConstraint(['story_id'], ['stories.id'], ondelete='CASCADE'),
    sa.ForeignKeyConstraint(['user_id'], ['users.id'], ondelete='CASCADE'),
    sa.PrimaryKeyConstraint('user_id', 'story_id')
    )
    op.create_table('story_summaries',
    sa.Column('id', sa.Integer(), nullable=False),
    sa.Column('story_id', sa.Integer(), nullable=False),
    sa.Column('title', sa.Text(), nullable=False),
    sa.Column('points', sa.JSON(), nullable=False),
    sa.Column('model', sa.String(length=64), nullable=False),
    sa.Column('prompt_version', sa.String(length=32), nullable=False),
    sa.Column('created_at', sa.DateTime(timezone=True), nullable=False),
    sa.ForeignKeyConstraint(['story_id'], ['stories.id'], ondelete='CASCADE'),
    sa.PrimaryKeyConstraint('id')
    )
    with op.batch_alter_table('story_summaries', schema=None) as batch_op:
        batch_op.create_index(batch_op.f('ix_story_summaries_story_id'), ['story_id'], unique=False)

    op.create_table('claims',
    sa.Column('id', sa.Integer(), nullable=False),
    sa.Column('story_id', sa.Integer(), nullable=False),
    sa.Column('item_id', sa.Integer(), nullable=False),
    sa.Column('statement', sa.Text(), nullable=False),
    sa.Column('subject', sa.String(length=200), nullable=False),
    sa.Column('value', sa.String(length=200), nullable=True),
    sa.Column('quote', sa.Text(), nullable=False),
    sa.Column('quote_language', sa.String(length=8), nullable=False),
    sa.Column('translation', sa.Text(), nullable=True),
    sa.Column('status', sa.String(length=16), nullable=False),
    sa.Column('relation', sa.String(length=16), nullable=True),
    sa.Column('related_claim_id', sa.Integer(), nullable=True),
    sa.Column('verifier_reason', sa.Text(), nullable=True),
    sa.Column('model', sa.String(length=64), nullable=False),
    sa.Column('prompt_version', sa.String(length=32), nullable=False),
    sa.Column('created_at', sa.DateTime(timezone=True), nullable=False),
    sa.Column('kept_at', sa.DateTime(timezone=True), nullable=True),
    sa.Column('superseded_at', sa.DateTime(timezone=True), nullable=True),
    sa.Column('superseded_by', sa.Integer(), nullable=True),
    sa.ForeignKeyConstraint(['item_id'], ['items.id'], ondelete='CASCADE'),
    sa.ForeignKeyConstraint(['related_claim_id'], ['claims.id'], ),
    sa.ForeignKeyConstraint(['story_id'], ['stories.id'], ondelete='CASCADE'),
    sa.ForeignKeyConstraint(['superseded_by'], ['claims.id'], ),
    sa.PrimaryKeyConstraint('id')
    )
    with op.batch_alter_table('claims', schema=None) as batch_op:
        batch_op.create_index(batch_op.f('ix_claims_item_id'), ['item_id'], unique=False)
        batch_op.create_index(batch_op.f('ix_claims_kept_at'), ['kept_at'], unique=False)
        batch_op.create_index(batch_op.f('ix_claims_status'), ['status'], unique=False)
        batch_op.create_index(batch_op.f('ix_claims_story_id'), ['story_id'], unique=False)

    op.create_table('disagreements',
    sa.Column('id', sa.Integer(), nullable=False),
    sa.Column('story_id', sa.Integer(), nullable=False),
    sa.Column('claim_a_id', sa.Integer(), nullable=False),
    sa.Column('claim_b_id', sa.Integer(), nullable=False),
    sa.Column('subject', sa.String(length=200), nullable=False),
    sa.Column('note', sa.Text(), nullable=False),
    sa.Column('created_at', sa.DateTime(timezone=True), nullable=False),
    sa.ForeignKeyConstraint(['claim_a_id'], ['claims.id'], ondelete='CASCADE'),
    sa.ForeignKeyConstraint(['claim_b_id'], ['claims.id'], ondelete='CASCADE'),
    sa.ForeignKeyConstraint(['story_id'], ['stories.id'], ondelete='CASCADE'),
    sa.PrimaryKeyConstraint('id'),
    sa.UniqueConstraint('claim_a_id', 'claim_b_id')
    )
    with op.batch_alter_table('disagreements', schema=None) as batch_op:
        batch_op.create_index(batch_op.f('ix_disagreements_story_id'), ['story_id'], unique=False)

    with op.batch_alter_table('sources', schema=None) as batch_op:
        batch_op.add_column(sa.Column('etag', sa.Text(), nullable=True))
        batch_op.add_column(sa.Column('last_modified', sa.Text(), nullable=True))
        batch_op.add_column(sa.Column('last_fetched_at', sa.DateTime(timezone=True), nullable=True))
        batch_op.add_column(sa.Column('next_fetch_at', sa.DateTime(timezone=True), nullable=True))
        batch_op.add_column(sa.Column('fetch_interval_s', sa.Integer(), nullable=False, server_default='3600'))
        batch_op.add_column(sa.Column('error_count', sa.Integer(), nullable=False, server_default='0'))
        batch_op.add_column(sa.Column('last_error', sa.Text(), nullable=True))
        batch_op.create_index(batch_op.f('ix_sources_next_fetch_at'), ['next_fetch_at'], unique=False)



def downgrade() -> None:
    with op.batch_alter_table('sources', schema=None) as batch_op:
        batch_op.drop_index(batch_op.f('ix_sources_next_fetch_at'))
        batch_op.drop_column('last_error')
        batch_op.drop_column('error_count')
        batch_op.drop_column('fetch_interval_s')
        batch_op.drop_column('next_fetch_at')
        batch_op.drop_column('last_fetched_at')
        batch_op.drop_column('last_modified')
        batch_op.drop_column('etag')

    with op.batch_alter_table('disagreements', schema=None) as batch_op:
        batch_op.drop_index(batch_op.f('ix_disagreements_story_id'))

    op.drop_table('disagreements')
    with op.batch_alter_table('claims', schema=None) as batch_op:
        batch_op.drop_index(batch_op.f('ix_claims_story_id'))
        batch_op.drop_index(batch_op.f('ix_claims_status'))
        batch_op.drop_index(batch_op.f('ix_claims_kept_at'))
        batch_op.drop_index(batch_op.f('ix_claims_item_id'))

    op.drop_table('claims')
    with op.batch_alter_table('story_summaries', schema=None) as batch_op:
        batch_op.drop_index(batch_op.f('ix_story_summaries_story_id'))

    op.drop_table('story_summaries')
    op.drop_table('read_state')
    with op.batch_alter_table('items', schema=None) as batch_op:
        batch_op.drop_index(batch_op.f('ix_items_story_id'))
        batch_op.drop_index(batch_op.f('ix_items_source_id'))
        batch_op.drop_index(batch_op.f('ix_items_published_at'))

    op.drop_table('items')
    with op.batch_alter_table('stories', schema=None) as batch_op:
        batch_op.drop_index(batch_op.f('ix_stories_updated_at'))

    op.drop_table('stories')
    with op.batch_alter_table('jobs', schema=None) as batch_op:
        batch_op.drop_index(batch_op.f('ix_jobs_status'))
        batch_op.drop_index(batch_op.f('ix_jobs_run_after'))

    op.drop_table('jobs')
