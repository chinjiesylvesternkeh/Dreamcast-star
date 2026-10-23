"""subscription plans

Revision ID: 0002
Revises: 0001
Create Date: 2026-10-23

"""
from alembic import op
import sqlalchemy as sa


revision = '0002'
down_revision = '0001'
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        'subscriptions',
        sa.Column('plan', sa.String(length=20), server_default='free', nullable=False),
    )


def downgrade() -> None:
    op.drop_column('subscriptions', 'plan')
