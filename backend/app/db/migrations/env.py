"""Alembic environment. Batch mode, because SQLite can't alter most columns in place."""

from alembic import context
from sqlalchemy import create_engine

from app.db.models import Base

url = context.config.get_main_option("sqlalchemy.url")


def run() -> None:
    if context.is_offline_mode():
        context.configure(url=url, target_metadata=Base.metadata, render_as_batch=True, literal_binds=True)
        with context.begin_transaction():
            context.run_migrations()
        return
    with create_engine(url).connect() as connection:
        context.configure(connection=connection, target_metadata=Base.metadata, render_as_batch=True)
        with context.begin_transaction():
            context.run_migrations()


run()
