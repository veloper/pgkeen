#!/usr/bin/env python3

"""    
# ---------------------------------------------------------------------------
# PostgreSQL extension configuration and management
# ---------------------------------------------------------------------------
# ADD this directory as first to resolve for PYTHONPATH
#
# INSTALLATION:
#   To install this tool for CLI use, copy or symlink it to a directory in your PATH:
#
#     cp ./docker/pg_tools.py /usr/local/bin/pg_tools
#     chmod +x /usr/local/bin/pg_tools
#
#   Or symlink:
#     ln -s $(pwd)/docker/pg_tools.py /usr/local/bin/pg_tools
#
#   Then invoke as:
#     pg_tools [COMMAND] [OPTIONS]
#
#   Requires: Python 3.8+, click, psycopg2
#
#   For help:
#     pg_tools --help
#     pg_tools conf --help
#     pg_tools initdb --help
"""


# ============================================================================================================
# CLI :: Tools
# ============================================================================================================
import difflib, functools, json, logging, os, re, shlex, stat, sys

from collections import OrderedDict
from contextlib import contextmanager
from dataclasses import Field, asdict, dataclass, field, fields
from functools import reduce
from pathlib import Path
from typing import (Any, Dict, Generator, List, Literal, NamedTuple, Optional, Self, Sequence, Set, Tuple, Union,
                    overload)

import click, psycopg2

from click import ClickException
from psycopg2 import pool
from psycopg2.extensions import connection as pg_connection
from psycopg2.extensions import cursor as pg_cursor
from psycopg2.extras import DictCursor, DictRow, register_json


logger = logging.getLogger(__name__)





@dataclass
class PostgresConfig():
    """Dataclass to hold PostgreSQL connection information"""
    user:     str = field(default_factory=lambda: os.getenv("POSTGRES_USER", "postgres"))
    password: str = field(default_factory=lambda: os.getenv("PGPASSWORD", "mysecretpassword"))
    host:     str = field(default_factory=lambda: os.getenv("POSTGRES_HOST", "localhost"))
    port:     str = field(default_factory=lambda: os.getenv("POSTGRES_PORT", "5432"))
    database: str = field(default_factory=lambda: os.getenv("POSTGRES_DB", "postgres"))
         
    @property
    def dsn(self) -> str: return self.connection_string
    
    @property            
    def fields(self) -> Tuple[Field, ...]: 
        return fields(self)
    
    @property
    def connection_string(self) -> str:
        constr : List[str] = ["postgresql://"]
        if self.user:
            if self.password:
                constr.append(f"{self.user}:{self.password}@")
            else:
                constr.append(f"{self.user}@")
        if self.host: constr.append(self.host)
        if self.port: constr.append(f":{self.port}")
        if self.database: constr.append(f"/{self.database}")

        return "".join(constr)
        
        
# ---------------------------------------------
# PostgreSQL client
# ---------------------------------------------


class PostgresClient:
    """PostgreSQL client with connection pooling and transaction management."""

    def __init__(
        self,
        dsn: str,
        min_connections: int = 1,
        max_connections: int = 10,
        application_name: Optional[str] = None,
    ) -> None:
        self.dsn = dsn
        self.min_connections = min_connections
        self.max_connections = max_connections
        self.application_name = application_name
        self._pool: Optional[pool.ThreadedConnectionPool] = None

    def _initialize_connection(self, conn: pg_connection) -> None:
        """Initialize the connection with JSON support and application name."""
        register_json(conn)
        if self.application_name:
            with conn.cursor() as cur:
                cur.execute("SET application_name = %s", (self.application_name,))

    def _get_pool(self) -> pool.ThreadedConnectionPool:
        """Get or create a connection pool."""
        if self._pool is None:
            try:
                self._pool = pool.ThreadedConnectionPool(
                    minconn=self.min_connections,
                    maxconn=self.max_connections,
                    dsn=self.dsn,
                )
            except psycopg2.OperationalError as e:
                logger.error("Failed to connect to PostgreSQL: %s", e)
                raise
        return self._pool

    @contextmanager
    def connection(self) -> Generator[pg_connection, None, None]:
        """Provide a connection from the pool."""
        pool_instance = self._get_pool()
        conn = pool_instance.getconn()
        try:
            self._initialize_connection(conn)
            yield conn
        finally:
            pool_instance.putconn(conn)

    @contextmanager
    def cursor(self, dict_cursor: bool = True) -> Generator[Union[DictCursor, pg_cursor], None, None]:
        """Provide a cursor from a connection."""
        with self.connection() as conn:
            cursor_factory = DictCursor if dict_cursor else None
            with conn.cursor(cursor_factory=cursor_factory) as curs:
                yield curs

    def execute(self, query: str, params: Optional[Union[Tuple, Dict]] = None) -> str:
        """Execute a query and return the status message."""
        with self.cursor() as cur:
            cur.execute(query, params)
            return cur.statusmessage or ""

    def fetch_all(self, query: str, params: Optional[Union[Tuple, Dict]] = None) -> Sequence[Union[DictRow, Tuple[Any, ...]]]:
        """Fetch all rows from a query."""
        with self.cursor() as cur:
            cur.execute(query, params)
            return cur.fetchall()

    def fetch_one(self, query: str, params: Optional[Union[Tuple, Dict]] = None) -> Optional[Union[DictRow, Tuple[Any, ...]]]:
        """Fetch one row from a query."""
        with self.cursor() as cur:
            cur.execute(query, params)
            return cur.fetchone()

    def fetch_value(self, query: str, params: Optional[Union[Tuple, Dict]] = None) -> Any:
        """Fetch a single value from a query."""
        with self.cursor(dict_cursor=False) as cur:
            cur.execute(query, params)
            row = cur.fetchone()
            if row is None:
                raise IndexError("Query returned no rows")
            return row[0]

    def close(self) -> None:
        """Close all connections in the pool."""
        if self._pool is not None:
            self._pool.closeall()
            self._pool = None
            logger.info("PostgreSQL connection pool closed")






# ---------------------------------------------
# Codec
# ---------------------------------------------

# Define the type for decoded values
DecodedValue = Optional[Union[str, int, float, bool]]
EncodedValue = str


class PostgresqlConfSettingCodec:
    """Codec pattern for decoding from and encoding to postgresql.conf file settings."""
    ESCAPE_TRIGGER_CHARS = [' ', '\t', '\n', '\r', '=', '#', ';', "'", '"', '*', '&', '|', 
                            '<', '>', '`', '~', '!', '@', '#', '$', '%', '^', '&', '*', '(', 
                            ')', '|', '{', '}', '[', ']', ':', ';', ',', '.', '?', '/']
    

    @classmethod
    def _is_escape_required_for(cls, value: str) -> bool:
        """Check if the value contains any trigger characters that require escaping."""
        chars = set(cls.ESCAPE_TRIGGER_CHARS)
        return any(char in value for char in cls.ESCAPE_TRIGGER_CHARS)

    @classmethod
    def _unescape(cls, value_just_after_parse: str) -> str:
        """Remove surrounding single quotes (if any), then unescapes single quotes."""
        return value_just_after_parse.strip().strip("'").replace("''", "'")

    @classmethod
    def _escape(cls, value_just_before_write: str) -> str:
        """Escape single quotes in the value, and add surrounding single quotes if needed."""
        if cls._is_escape_required_for(value_just_before_write):
            return "'%s'" % value_just_before_write.replace("'", "''")
        return value_just_before_write


    @classmethod
    def decode(cls, encoded: str) -> DecodedValue:

        # Unescape for converting to the correct type
        unescaped = cls._unescape(encoded)


        if unescaped in ("on", "true", "yes"): return True
        if unescaped in ("off", "false", "no"): return False

        # Numbers (order matters)
        if re.compile(r"^[+-]?\d*(\.\d+)?[eE[+-]?\d+$").match(unescaped): return unescaped # String -- Leave it alone
        if re.compile(r"^[+-]?\d*(\.\d+)?$").match(unescaped): return float(unescaped) # FLOAT
        if re.compile(r"^[+-]?\d+$").match(unescaped): return int(unescaped) # INT

        # The rest come through as strings
        return unescaped


    @classmethod
    def encode(cls, value: DecodedValue) -> str:
        """Inversion of decode."""
        converted : Optional[str] = None
        if isinstance(value, bool):
            converted = "on" if value else "off"
        elif isinstance(value, (int, float)):
            converted = str(value)

        elif isinstance(value, str):
            converted = value
        else:
            raise ValueError(f"Value must be of DecodedValue, not {type(value)}")

        # Escape for writing to the configuration file
        return  cls._escape(converted)


# ---------------------------------------------
# Repository and Entity
# ---------------------------------------------

@dataclass
class EntityBase:
    """Base class for entities with basic additional dataclass convenience methods."""
    
    @classmethod
    def build(cls, **kwargs) -> Self: return cls(**kwargs)

    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> Self: return cls(**data)
        
    @classmethod
    def fields(cls) -> Tuple[Field,...]: return fields(cls)
    
    def get_fields(self) -> Tuple[Field,...]: return self.__class__.fields()
    
    def to_dict(self) -> Dict[str, Any]: return asdict(self)
    
@dataclass
class SettingFields:
    """Just the fields for a setting."""
    key: str
    value: DecodedValue
    comment: str | None = None
    original_line: str | None = None
    
class BaseSetting(SettingFields):
    """Mixin class for Setting and SettingSnapshot.
    
    Adds the fields, and drys out the downstream implementations.
    """

    @property
    def exists(self) -> bool: return True if self.original_line else False 
    
    @property
    def is_new(self) -> bool: return not self.exists
    
    @property
    def encoded_value(self) -> EncodedValue: return PostgresqlConfSettingCodec.encode(self.value) 
    
    
    def to_encoded_line(self) -> str: 
        return " ".join(filter(None,[
            self.key,
            "=",
            self.encoded_value,
            (f"# {self.comment}" if self.comment else None),
        ])).strip() + "\n"
    
    
    def has_value(self) -> bool: return bool(self.value)
    
    def value_as_list(self, *, delimiter: str = ",") -> List[str]:
        """Convert the current value to a list of strings, unless value is currently a Bool."""
        if not self.has_value(): return [] # Short circuit if no value
        
        # Check if the value is something that _can_ be converted to a string.
        if not isinstance(self.value, str | int | float):
            raise ValueError(f"Cannot convert existing value of type {type(self.value)} to a list as it may cause unexpected conversion issues.")
        
        # Coerce to string
        value = str(self.value)
        
        # Split and return
        return [v.strip() for v in value.split(delimiter) if v.strip()]
        
        
        
    
    @overload
    def with_value(self, value: DecodedValue) -> Self: 
        """Set the DecodedValue (int, float, bool, str) of the setting."""
        ...
    
    @overload
    def with_value(self, value: List[str], delimiter: str = ",", append: bool = False, deduplicate: bool = True) -> Self:
        """Set the value of the setting as a list of strings, with optional delimiter, append|replace, and deduplicate options."""
        ...
    
    def with_value(self, value: Union[DecodedValue, List[str]], delimiter: str = ",", append: bool = False, deduplicate: bool = True) -> Self:
        """Overloaded implementation for both single value and list-like value assignment/update"""
        
        if isinstance(value, DecodedValue):
            self.value = value
        elif isinstance(value, list) and all(isinstance(v, (str)) for v in value):
            existing_values : List[str] = self.value_as_list(delimiter=delimiter)
            new_values : List[str] = [str(v) for v in value]

            # Replace or Append?
            values : List[str] = new_values if not append else existing_values + new_values
            
            # Deduplicate
            if deduplicate:
                values = list(OrderedDict.fromkeys(values).keys())
            
            self.value = delimiter.join(values)    
        else:
            raise ValueError(f"Value must be a single value, or a list of strings, not {type(value)}")
            
        return self
            
                
    def with_comment(self, comment: Optional[str]) -> Self: 
        self.comment = comment; return self
    

@dataclass
class Setting(EntityBase, BaseSetting):
    """Record for a PostgreSQL configuration setting."""
        
    
    
    def to_snapshot(self) -> "SettingSnapshot":
        """Create a frozen copy of the current setting."""
        return SettingSnapshot( key=self.key, value=self.value, comment=self.comment, original_line=self.original_line )
    
@dataclass
class SettingSnapshot(BaseSetting):
    """Sorta "Immutable" snapshot of a PostgreSQL configuration setting."""
    
    def with_value(self, value: DecodedValue) -> Self:
        raise ValueError("Cannot modify a snapshot of a setting.")
    
    def with_comment(self, comment: Optional[str]) -> Self:
        raise ValueError("Cannot modify a snapshot of a setting.")
    
    
    

@dataclass(frozen=True) # Make the dataclass immutable after creation
class LineSettingMatch:
    """Dataclass to hold the regex match groups for a configuration setting line."""

    line: str # original line captured by the regex

    key:                   str
    assignment:            str
    value:                 str
    value_quotes:          str
    post_value_whitespace: str
    comment:               str
    eol:                   str
    encoded_value:         str


    def to_setting_record(self) -> Setting:
        """Convert the LineSettingMatch to a Setting object."""
        return Setting(
            key=self.key,
            value=PostgresqlConfSettingCodec.decode(self.value),
            comment=self.comment,
            original_line=self.line
        )


    @classmethod
    def from_match(cls, match: re.Match) -> Self:
        """Create a ConfSettingRecord instance from a regex match object."""
        match_dict = match.groupdict()
        match_dict["line"] = match[0]
        return cls(**match_dict)


class Change(NamedTuple):
    """Base class for changes to be applied to the configuration file."""
    type: Literal["create", "update", "delete"]
    setting: SettingSnapshot
    
    @property
    def is_delete(self) -> bool: return self.type == "delete"
    @property
    def is_update(self) -> bool: return self.type == "update"
    @property
    def is_create(self) -> bool: return self.type == "create"
    
        
    
    def apply_to(self, proposed_content: str) -> str:
        """Apply the change to the proposed content string."""
        if self.is_create:
            # Append new setting at the end
            return proposed_content + self.setting.to_encoded_line()
        else:
            if not self.setting.original_line:
                raise ValueError("Cannot update or delete a setting without an original line.")
    
            # Reverse lines for update/delete to target the last occurrence
            lines = proposed_content.splitlines(keepends=True)
            lines.reverse()
            for idx, line in enumerate(lines):
                if line == self.setting.original_line:
                    if self.is_update:
                        lines[idx] = self.setting.to_encoded_line()
                    elif self.is_delete:
                        lines.pop(idx)
                    break
            lines.reverse()
            return "".join(lines)
        
        
        
        

@dataclass
class ChangeSet:
    """Manages pending changes to the PostgreSQL configuration."""

    _changes: List[Change] = field(default_factory=list)


    def append(self, type_: Literal["create", "update", "delete"], setting: Setting) -> Self:
        """Append a change to the changeset."""
        change = self._build_change(type_, setting)
        self._changes.append(change)
        return self

    def _build_change(self, type_: Literal["create", "update", "delete"], setting: Setting) -> Change:
        """Build a change object."""
        if not isinstance(setting, Setting):
            raise ValueError("Setting must be an instance of Setting.")
        
        return Change(type=type_, setting=setting.to_snapshot())

    def create(self, setting: Setting) -> Self: return self.append("create", setting)
    def update(self, setting: Setting) -> Self: return self.append("update", setting)
    def delete(self, setting: Setting) -> Self: return self.append("delete", setting)

    
    def apply_to(self, proposed_content: str) -> str: 
        return reduce(lambda content, change: change.apply_to(content), self._changes, proposed_content)
    
    

@dataclass
class SettingRepository:
    """Manages PostgreSQL configuration file settings.

    This class provides functionality to parse, modify, and persist settings
    in a PostgreSQL configuration file. It acts as a repository for settings,
    handling parsing, editing, and rendering of the configuration file.

    Attributes:
        path (Path): Path to the configuration file.
        line_setting_matches (List[LineSettingMatch]): Parsed settings from the file.
        change_set (ChangeSet): Manages pending changes.
    """

    path: Path # required

    line_setting_matches: List[LineSettingMatch] = field(default_factory=list)
    change_set: ChangeSet = field(default_factory=ChangeSet)

    RE_BITWISE_TO_NAME : Dict[int, str] = field(default_factory=dict)

    PATTERN = re.compile("".join([
        r"^"
        r"(?!#)",                       # no commented-out lines
        r"(?P<key>[\w_\.]+)",
        r"(?P<assignment>\s+?=\s+?)",
        r"(?P<encoded_value>",
            r"(?P<value_quotes>[\"'])?",
            r"(?P<value>.*?)",
            r"(?P=value_quotes)?",
        r")",
        r"(?P<post_value_whitespace>(\s|\t))*?", # optional whitespace
        r"(?P<comment>\#.*?)?", # optional non-greedy comment
        r"(?P<eol>\n|$)" # detect both newlines and end of file
    ]), re.MULTILINE)

    def __post_init__(self):
        self.reload()

    def reload(self) -> Self:
        # Freshly read
        self.content = self.path.read_text()

        # Parse LineSettingRecords
        self.line_setting_matches = [LineSettingMatch.from_match(match) for match in self.PATTERN.finditer(self.content)]

        # Reset the change set
        self.change_set = ChangeSet() 

        return self

    # -----------------------------------
    # Helpers 
    # ----------------------------------

    def get_value(self, key: str, default: DecodedValue = None) -> DecodedValue:
        """Get the value of a setting by its key."""
        if entity := self.find(key):
            return entity.value
        else:
            return default
    
    def set_value(self, key: str, value: DecodedValue) -> Self:
        """Set the value of a setting by its key."""
        
        entity = self.find_or_build(key)
        entity.value = value
        
        # Persist the change
        self.persist(entity)
        
        
        return self


    # -----------------------------------
    # Record Interaction
    # -----------------------------------
    
    def update_or_build_pairs(self, pairs: Dict[str, DecodedValue]) -> List[Setting]:
        """Update or build settings from a dictionary of key=value pairs."""
        return [
            self.update_or_build(key, value) for key, value in pairs.items()
        ]
    
    
    def update_or_build(self, key: str, value: DecodedValue, comment: Optional[str] = None) -> Setting:
        """Update an existing setting or build a new one."""
        existing_setting = self.find(key)
        if existing_setting:
            return existing_setting.with_value(value).with_comment(comment)
        else:
            return self.build(key, value, comment)
    
    def find_or_build(self, key: str) -> Setting:
        """Find an existing setting or build a new one."""
        existing_setting = self.find(key)
        if existing_setting:
            return existing_setting
        else:
            return self.build(key, None, None)
            

    def build(self, key: str, value: DecodedValue, comment: Optional[str] = None) -> Setting:
        """Build a new Setting object from the current state of the repository."""
        return Setting(key=key, value=value, comment=comment)


    def find(self, key: str) -> Optional[Setting]:
        """Find the last existing setting record by its key."""
        return next(iter([lsm.to_setting_record() for lsm in reversed(self.line_setting_matches) if lsm.key == key]), None)

    def findall(self) -> List[Setting]:
        """Find all existing setting records"""
        return [lsm.to_setting_record() for lsm in self.line_setting_matches]


    # ----------------------------------------------------------------------------
    # Pending Changes - Delegating to ChangeSet
    # ----------------------------------------------------------------------------

    def persist(self, setting: Setting) -> Self:
        """Mark a setting for update or create."""
        if setting.is_new:
            self.change_set.create(setting)
        else:
            self.change_set.update(setting)
        return self
    
    def remove(self, setting: Setting) -> Self:
        """Mark a setting for deletion."""
        if setting.is_new:
            raise ValueError("Cannot remove a new setting that has not been persisted.")
        
        if setting.exists:
            self.change_set.delete(setting)
        return self
        

    
    
    # ----------------------------------------------------------------------------
    # Proposed Change related methods
    # ----------------------------------------------------------------------------

    @property
    def proposed_content(self) -> str:
        """Get the proposed content with all changes applied."""
        return self.change_set.apply_to(self.content)
    
    
    def proposed_diff(self, ansi_color: bool = False) -> str:
        """Get the diff between the original content and the updated content."""
        original_content = self.content.splitlines(keepends=True)
        updated_content = self.proposed_content.splitlines(keepends=True)

        diff = difflib.unified_diff(original_content, updated_content, fromfile="original", tofile="proposed" )

        if ansi_color:
            # ANSI color codes
            RED    = '\033[0;31m'
            GREEN  = '\033[0;32m'
            CYAN   = '\033[0;36m'
            RESET  = '\033[0m'

            diff_output_lines = []
            for line in diff:
                if line.startswith('+'):
                    diff_output_lines.append(GREEN + line + RESET)
                elif line.startswith('-'):
                    diff_output_lines.append(RED + line + RESET)
                elif line.startswith('@@'):
                    diff_output_lines.append(CYAN + line + RESET)
                elif line.startswith('---') or line.startswith('+++'):
                    diff_output_lines.append(CYAN + line + RESET)
                else:
                    diff_output_lines.append(line)
            diff_output = ''.join(diff_output_lines)
        else:
            diff_output = ''.join(diff)
        return diff_output

    def flush(self) -> Self:
        """Save the changes to the file."""
        
        original_content = self.content
        proposed_content = self.change_set.apply_to(original_content)
        
        if proposed_content == original_content:
            return self
        
        self.path.write_text(proposed_content)
        self.reload()

        return self


    @property
    def regex_pattern_flags(self) -> List[str]:
        pattern = self.__class__.PATTERN
        return [value for key, value in self.RE_BITWISE_TO_NAME.items() if key & pattern.flags == key]


    @property
    def regex_pattern(self) -> re.Pattern:
        return self.__class__.PATTERN

    def __repr__(self):
        return "%s( PATTERN = (%s), FLAGS = (%s) )" % (self.__class__.__name__, self.regex_pattern.pattern, "|".join(self.regex_pattern_flags),)

# -------------------------------------------------------------------------------------------------------------
# -------------------------------------------------------------------------------------------------------------
# -------------------------------------------------------------------------------------------------------------
# -------------------------------------------------------------------------------------------------------------
#
# BEGIN CLI
#
# -------------------------------------------------------------------------------------------------------------
# -------------------------------------------------------------------------------------------------------------
# -------------------------------------------------------------------------------------------------------------
# -------------------------------------------------------------------------------------------------------------

class ClickError(ClickException):
    def __init__(self, message, exit_code=1):
        super().__init__(message)
        self.exit_code = exit_code


@click.group()
def cli():
    r"""
     _____   _____   _______          _       
    |  __ \ / ____| |__   __|        | |      
    | |__) | |  __     | | ___   ___ | |___   
    |  ___/| | |_ |    | |/ _ \ / _ \| / __|  
    | |    | |__| |    | | (_) | (_) | \__ \  
    |_|     \_____|    |_|\___/ \___/|_|___/  
                                                  
    PG Tools - PostgreSQL Docker CLI Utilities 
    
    Build time helpers for ensuring the PostgreSQL Docker image is configured the way you want.
    
    Installation:
        COPY path/to/pg_tools.py /usr/local/bin/pg_tools
        CHMOD +x /usr/local/bin/pg_tools
    """
    pass

# =============================================================================================================
# CLI :: Conf Namespace
# =============================================================================================================
               

class ConfContext:
    """Postgres Docker Configuration context."""

    def __init__(self):
        self._postgres_conf_path = None
        self._repo = None

    @property
    def pgdata_value(self) -> str | None: return os.getenv("PGDATA")
        
    
    @property
    def pgdata_path(self) -> Path:
        if pgdata_value := self.pgdata_value:
            return Path(pgdata_value).absolute()
        raise ClickError("PGDATA environment variable not set, You're probably not running this from the correct context.")
            
    @property
    def postgresql_conf_path(self) -> Path: 
        if not self._postgres_conf_path:
            self._postgres_conf_path = self.pgdata_path / "postgresql.conf"
        return self._postgres_conf_path
        

    @property
    def repo(self) -> SettingRepository:
        if self._repo is None:
            self._repo = SettingRepository(self.postgresql_conf_path)
        return self._repo

@cli.group()
@click.pass_context
def conf(ctx):
    """Manage postgresql.conf settings."""
    ctx.obj = ConfContext()

@conf.command("info")
@click.pass_obj
def conf_info(ctx: ConfContext):
    """Show the current configuration file path and settings as json."""
    click.echo(f"Configuration file: {ctx.repo.path}")
    dicts = [setting.to_dict() for setting in ctx.repo.findall()]
    click.echo(f"- Settings Count: {len(dicts)}")
    click.echo(f"- Settings JSON: {json.dumps(dicts, indent=2)}")


@conf.command("get")
@click.argument("key")
@click.pass_obj
def conf_get(ctx: ConfContext, key: str):
    val = ctx.repo.get_value(key)
    if val is None:
        raise ClickError(f"Setting '{key}' not found.")
    click.echo(val)

@conf.command("set")
@click.argument("args", nargs=-1)
@click.option("--comment", default="", help="Optional comment, if used w/ multi-set variant, it's applied to all.")
@click.option("--silent", is_flag=True, default=False, help="Suppress output.")
@click.option("--dry-run", is_flag=True, default=False, help="Show the diff without applying changes.")
@click.pass_obj
def conf_set(ctx: ConfContext, args: List[str], comment: str = "", silent: bool = False, dry_run: bool = False):
    """Set one or more settings.
    Usage:
      pg_tools conf set key value [--comment ...] [--silent] [--dry-run]
      pg_tools conf set key1=val1 key2=val2 ... [--comment ...] [--silent] [--dry-run]
    """
    if not args: raise ClickError("At least one argument required.")
    
    
    def echo(msg: str): 
        if not silent: click.echo(msg)
    
    # TypeGuard Checks (picked up by linters)
    is_single = isinstance(args[0], str) and isinstance(args[1], str) and "=" not in args[0] 
    is_multi =  not is_single and len(args) > 1 and all(isinstance(arg, str) and "=" in arg for arg in args)

    # Normalize the arguments    
    settings : List[Setting] = []
    if is_single:
        echo(f"Single setting detected.")
        settings.append(ctx.repo.update_or_build(args[0], args[1], comment or None))
    elif is_multi:
        echo(f"Multi setting detected.")
        pairs : Dict[str, DecodedValue] = {k: v for arg in args for k, v in [arg.split("=", 1)]}
        settings.extend(ctx.repo.update_or_build_pairs(pairs))        
    else:
        raise ClickError("Invalid signature, see --help for usage.")
    
    # Persist
    for setting in settings: 
        ctx.repo.persist(setting)

    if not silent:
        echo("\nChange Summary:")
        echo(ctx.repo.proposed_diff(ansi_color=True))
        
    if dry_run:
        echo("\nDry run complete, no changes made to the configuration file.")
        return

    # Flush the changes to the file
    ctx.repo.flush() 
      
@conf.command("upsert")
@click.argument("key")
@click.argument("values", nargs=-1)
@click.option("--delimiter", default=",", help="Delimiter for the list.")
@click.option("--method", type=click.Choice(["append", "replace"]), default="append", help="Method by which to apply the changes.")
@click.option("--deduplicate", is_flag=True, default=False, help="Remove duplicate values from the final value's list items.")
@click.option("--comment", default=None, help="Optional comment appearing after at the end of the line in the config file.")
@click.option("--silent", is_flag=True, default=False, help="Suppress output.")
@click.option("--dry-run", is_flag=True, default=False, help="Hold short of flushing the changes the command would make normally.")
@click.pass_obj
def conf_upsert(
    ctx: ConfContext,
    key: str,
    values: List[str],
    delimiter: str = ",",
    method: Literal["append", "replace"] = "append",
    deduplicate: bool = False,
    comment: Optional[str] = None,
    silent: bool = False,
    dry_run: bool = False
) -> None:
    """
    Upsert (update or create) a PostgreSQL configuration setting with a value that is list-like.

    This command allows you to append to or replace the list of values for a given setting key
    in postgresql.conf. It supports deduplication and custom delimiters.

    Args:
        ctx (ConfContext): The CLI context object providing access to the repository.
        key (str): The configuration key to upsert.
        values (List[str]): One or more values to append or set for the key.
        delimiter (str, optional): Delimiter to use when joining list values. Defaults to ",".
        method (Literal["append", "replace"], optional): Whether to append to or replace the existing value. Defaults to "append".
        deduplicate (bool, optional): If True, remove duplicate values (preserving order). Defaults to False.
        comment (Optional[str], optional): Optional comment to append to the setting line. Defaults to None.
        silent (bool, optional): If True, suppress output. Defaults to False.
        dry_run (bool, optional): If True, show the diff but do not write changes. Defaults to False.

    Usage:
        pg_tools conf upsert key value1 value2 ... [--method=append|replace] [--delimiter=,] [--deduplicate] [--comment="..."] [--silent] [--dry-run]

    Examples:
        pg_tools conf upsert shared_preload_libraries pg_stat_statements --method=append --deduplicate
        pg_tools conf upsert search_path public,extensions --method=replace --delimiter=','

    Behavior:
        - If method 
            - is "append", values are added to the existing list.
            - is "replace", values replace the existing list.
        - If --deduplicate is set, duplicate values are removed, preserving the first occurrence.
        - If --dry-run is set, the proposed changes are shown but not written.
        - If --silent is set, output is suppressed.
        - If --comment is provided, it is added to the end of the setting line.
    """
    
    if not values: raise ClickError("At least one value is required.")
    
    # Coerce the values to a list of strings
    values = [str(v) for v in values]
            
    def echo(msg: str): 
        if not silent: click.echo(msg)
        
    
    # Get the setting, or create a new one
    setting = ctx.repo.find_or_build(key)
    
    
    # Ensure the proper approach is being user
    should_append = (method == "append")
    
    
    setting.with_value(
        values,
        delimiter=delimiter,
        append=should_append,
        deduplicate=deduplicate,
    )
    
    if comment:
        setting = setting.with_comment(comment)
        
    # Persist the change
    ctx.repo.persist(setting)
    
    
    if not silent:
        echo("\nChange Summary:")
        echo(ctx.repo.proposed_diff(ansi_color=True))
        
        
    if dry_run:
        echo("\nDry run complete, no changes made to the configuration file.")
        return
    
    # Flush the changes to the file
    ctx.repo.flush()
    
    echo(f"Setting '{key}' updated successfully.")

    

@conf.command("unset")
@click.argument("key")
@click.pass_obj
def conf_unset(ctx: ConfContext, key: str):
    if setting := ctx.repo.find(key):
        ctx.repo.remove(setting).flush()
    # noop
    
@conf.command("list")
@click.pass_obj
def conf_list(ctx: ConfContext):
    for s in ctx.repo.findall():
        click.echo(f"{s.key} = {s.value} {'# ' + s.comment if s.comment else ''}")

# =============================================================================================================
# CLI :: Initdb Namespace
# =============================================================================================================

class InitdbContext:
    """Context for managing initdb scripts."""
    def __init__(self):
        self._initdb_path = None
        self._allowed_extensions : Tuple[str, ...] = (".sh", ".sql", ".sql.gz", ".sql.xz", ".sql.zst")
        self._config_context : ConfContext = ConfContext()

    @property
    def config_context(self) -> ConfContext:
        if self._config_context is None:
            self._config_context = ConfContext()
        return self._config_context


    @property
    def initdb_path(self) -> Path:
        if self._initdb_path is None:
            path = Path("/docker-entrypoint-initdb.d")
            if not path.exists():
                raise ClickError(f"Initdb path '{path}' does not exist.")
            self._initdb_path = path
        return self._initdb_path
    
    @property
    def files(self) -> List[Path]:
        """File that will be run in the order of operations per the official docker image of pg:16"""
        paths = [f for f in self.initdb_path.iterdir() if f.name.endswith(self._allowed_extensions)]
        return sorted(paths, key=lambda f: f.name) 
    
    def normalize_name(self, name: str, ext: str, allowed_ext : Tuple[str, ...] | None = None) -> str:
        """Normalize the name of the file to be created."""
        if allowed_ext is None:
            allowed_ext = self._allowed_extensions
            
        if ext not in allowed_ext:
            raise ClickError(f"Extension '{ext}' is not allowed. Allowed extensions are: {', '.join(allowed_ext)}")
        
        # Normalize the name to alphanumeric snake_case
        name = re.sub(r"[^a-zA-Z0-9_]", "_", name)
        
        # We will not be cleaning up repeated underscores, as that can easily lead to unexpected behavior
        name = name.lower()        
        return f"{name}.{ext}"
    
    def ensure_hashbang(self, content: str, *, if_missing: str = "#!/bin/bash") -> str:
        """Ensure the content has a hashbang at the beginning. Default is #!/bin/bash."""
        return content if content.startswith("#!") else f"{if_missing}\n{content}"
        

@cli.group()
@click.pass_context
def initdb(ctx):
    """Manage postgresql.conf settings."""
    ctx.obj = InitdbContext()
     
     

@initdb.command("list")
def initdb_list(ctx: InitdbContext):
    """List initdb scripts as absolute paths on newlines."""
    for f in ctx.files:
        click.echo(str(f.resolve()))
    
@initdb.command("upsert")
@click.argument("name")
@click.argument("ext", type=click.Choice(["sql", "sh"])) # only ones allowed through this helper
@click.argument("content") 
@click.option("--silent", is_flag=True, default=False, help="Suppress output.")
@click.pass_obj
def initdb_upsert(ctx: InitdbContext, name: str, ext: str, content: str, silent: bool = False):
    """Create or Overwrite an initdb script using a unique name, extension (sql|sh), and content from a STRING passed in as the third argument."""
    if not content: raise ClickError("Content is required.")
    if not name or not ext:
        raise ClickError("Name and extension are required.")
    
    def echo(msg: str): 
        if not silent: click.echo(msg)
    
    # Normalize the name
    normalized_name = ctx.normalize_name(name, ext, allowed_ext=("sql", "sh"))
    
    # Ensure file exists (for upserting)
    file_path = ctx.initdb_path / normalized_name
    file_path.touch(exist_ok=True)
    
    
    # Set the _executable bit_ if the file is a shell script -- sql files are not executable
    if ext.endswith(".sh"):
        current_permissions = stat.S_IMODE(os.lstat(file_path).st_mode)
        new_permissions = current_permissions | stat.S_IXUSR | stat.S_IXGRP | stat.S_IXOTH
        os.chmod(file_path, new_permissions)
        content = ctx.ensure_hashbang(content)
    
    
    # Write the content to the file
    file_path.write_text(content)
    
    truncated_for_echo = content[:25] + "... (truncated)" if len(content) > 25 else content
    echo(f"File '{file_path}' created with content:\n{truncated_for_echo}")
    

# =============================================================================================================
# CLI :: Trunk Namespace
# =============================================================================================================

@dataclass
class TrunkPackage:
    """Represents a Trunk package."""
    name: str # trunk package name
    ext: str # postgresql extension name
    description: str | None = None
    version: str | None = None

    
    

@dataclass
class TrunkManifest:
    """Represents the trunk_manifest.json file."""
    json_path: Path
    
    
    

class TrunkContext:
    """Context for managing the Trunk CLI."""
    
    def __init__(self):
        self.manifest_path = Path("/etc/postgresql/trunk.json")

    
@cli.group()
def trunk():
    """Trunk is a postgres extension package manager."""
    pass


    
# ---------------------------
# MAIN ENTRYPOINT
# ---------------------------
def main():
    cli()

if __name__ == "__main__":
    main()


# def debug_locally():
#     """Debug the CLI locally."""
    
#     conf_file = Path(__file__).parent / "postgresql.conf.sample"
    
#     orig_repo = SettingRepository(conf_file)
    
#     from rich.console import Console
#     from rich.table import Table
    
#     console = Console()
    
#     def output_settings(repository: SettingRepository):
#         settings = repository.findall()
        
#         table = Table(title="PostgreSQL Settings",show_lines=True)
#         table.add_column("Key", justify="left", style="cyan")
#         table.add_column("Value", justify="left", style="magenta")
#         table.add_column("Comment", justify="left", style="green")
#         table.add_column("Original Line", justify="left", style="yellow")
        
#         for setting in settings:
#             table.add_row(
#                 setting.key,
#                 str(setting.value),
#                 setting.comment or "",
#                 setting.original_line or ""
#             )
            
#         console.print(table)
#         console.print(f"Total settings: {len(settings)}")
#         console.print(f"Repository path: {repository.path}")
        
#     output_settings(orig_repo)
    
#     # testing the logic of upserting a new non-existing setting
#     new_setting = orig_repo.update_or_build("test_setting", "test_value", "This is a test setting.")
#     orig_repo.persist(new_setting)
#     orig_repo.flush()
    
#     fresh_repo = SettingRepository(conf_file)
    
#     output_settings(fresh_repo)

# if __name__ == "__main__":
#     debug_locally()
#     # cli()
