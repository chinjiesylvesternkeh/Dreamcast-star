"""dream reports (AI-generated content flags)

Revision ID: 0003
Revises: 0002
Create Date: 2026-10-23

"""
from alembic import op
import sqlalchemy as sa


revision = '0003'
down_revision = '0002'
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table('dream_reports',
    sa.Column('id', sa.UUID(as_uuid=False), nullable=False),
    sa.Column('dream_id', sa.UUID(as_uuid=False), nullable=False),
    sa.Column('reason', sa.String(length=40), nullable=False),
    sa.Column('details', sa.Text(), nullable=True),
    sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('(CURRENT_TIMESTAMP)'), nullable=True),
    sa.Column('resolved', sa.Boolean(), nullable=True),
    sa.ForeignKeyConstraint(['dream_id'], ['dreams.id'], ),
    sa.PrimaryKeyConstraint('id')
    )
    op.create_index(op.f('ix_dream_reports_dream_id'), 'dream_reports', ['dream_id'], unique=False)


def downgrade() -> None:
    op.drop_index(op.f('ix_dream_reports_dream_id'), table_name='dream_reports')
    op.drop_table('dream_reports')
