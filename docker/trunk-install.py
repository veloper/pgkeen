#!/usr/bin/env python3

# -----------------------------------------------------------------------------
# Trunk Install Script for Postgres Extensions
#
# Purpose:
#   This script wraps 'trunk install' with the correct Postgres configuration
#   paths and options for building and installing extensions in Docker or
#   minimal environments.
#
#   It ensures trunk is invoked with the appropriate flags for Postgres 16.
#
# Installation:
#   1. Place this script somewhere in your PATH.
#      For example, in your Dockerfile:
#         COPY docker/trunk-install.py /usr/local/bin/trunk-install
#         RUN chmod +x /usr/local/bin/trunk-install
#
#   2. Ensure /usr/local/bin is in your PATH.
#
# Cleanup:
#   If you no longer need this script, simply remove it:
#      rm -f /usr/local/bin/trunk-install
#
# -----------------------------------------------------------------------------

import fcntl, json, logging, os, pprint, re, subprocess, sys, time

from abc import ABC, abstractmethod
from collections import OrderedDict, UserList
from contextlib import contextmanager
from dataclasses import asdict, dataclass, field, fields, is_dataclass, replace
from functools import lru_cache
from importlib.util import module_from_spec, spec_from_file_location
from pathlib import Path
from typing import (Any, Callable, Dict, Generator, Generic, Iterable, List, Literal, Mapping, Optional, Protocol, Self,
                    Sequence, Tuple, Type, TypeVar, Union, cast, runtime_checkable)

import click


DEST_DIR = "destination_dir"
SOURCE_REL_PATH = "source_rel_path"



logger = logging.getLogger(__name__)
if not logger.hasHandlers():
    handler = logging.StreamHandler(sys.stdout)
    handler.setFormatter(logging.Formatter('%(asctime)s %(levelname)s %(message)s'))
    logger.addHandler(handler)
logger.setLevel(logging.DEBUG)



def format_context(context: Any) -> str:
    """Format context in a way that rich does but using custom code as the environment does not allow rich to be installed"""
    
    def extract_property_values(subject: Type | object, private: bool = False) -> Dict[str, Any]:
        """Extracts property values from a class or instance"""
        klass = subject if isinstance(subject, type) else type(subject)
        properties = {}
        for name in dir(klass):
            if name.startswith('__') and name.endswith('__'): continue # no dunder methods
            if not private and name.startswith('_'): continue          # optional: skip private attributes
                
            if isinstance(getattr(klass, name, None), property):
                try:
                    properties[name] = getattr(subject, name)
                except Exception as e:
                    properties[name] = f"<??? error while accessing property: {e} ???>"
        return properties
        
    def extract_field_values(subject: object) -> Dict[str, Any]:
        if is_dataclass(subject) and isinstance(subject, object) and not isinstance(subject, type):
            return asdict(subject)
        raise TypeError(f"Expected a dataclass instance, got {type(subject)}")
            
        
    
    def _format_value(value, indent_level=0):
        tab = ' ' * 4
        indent = tab * indent_level
        
        
        if value is None:
            return "None"
        elif isinstance(value, (str, bytes)):
            # Handle multiline strings with triple quotes
            if isinstance(value, bytes):
                value = value.decode('utf-8', errors='replace')
            if "\n" in value:
                lines = value.split("\n")
                # Format with triple quotes and proper indentation
                result = "'''\n"
                for line in lines:
                    result += f"{indent}{tab}{line}\n"
                result += f"{indent}'''"
                return result
            else:
                return f"'{value}'"
        elif isinstance(value, (int, float, bool)):
            return str(value)
        elif isinstance(value, (list, tuple)):
            if not value:
                return "[]" if isinstance(value, list) else "()"
            
            result = "[\n"
            for item in value:
                result += f"{indent}{tab}{_format_value(item, indent_level + 1)},\n"
            result += f"{indent}]"
            return result
        elif isinstance(value, dict):
            if not value:
                return "{}"
            
            result = "{\n"
            for k, v in value.items():
                result += f"{indent}{tab}{k!r}: {_format_value(v, indent_level + 1)},\n"
            result += f"{indent}}}"
            return result
        elif isinstance(value, Path):
            return f"Path({str(value)})"
        elif isinstance(value, Path):
            return f"Path({str(value)})"
        elif is_dataclass(value) and isinstance(value, object) and not isinstance(value, type): # linting requires this level type narrowing
            result = f"{indent}{value.__class__.__name__}( # @dataclass\n"
            
            
            data: Dict[str, Any] = { **extract_property_values(value), **extract_field_values(value) }
                    
            for key, val in data.items():
                result += f"{indent}{tab}{key}={_format_value(val, indent_level + 1)},\n"
                
            result += f"{indent})"

            return result
        elif isinstance(value, Iterable) and not isinstance(value, (str, bytes)):
            # Handle iterables (excluding strings and bytes)
            result = "[\n"
            for item in value:
                result += f"{indent}{tab}{_format_value(item, indent_level + 1)},\n"
            result += f"{indent}]"
            return result
        elif isinstance(value, type):
            # Handle class types
            return f"{value.__module__}.{value.__name__}"
        else:
            # Try to use the object's __dict__ if available
            try:
                if hasattr(value, '__dict__'):
                    attrs = vars(value)
                    result = f"{value.__class__.__name__}(\n"
                    for attr, val in attrs.items():
                        if not attr.startswith('_'):  # Skip private attributes
                            result += f"{indent}{tab}{attr}={_format_value(val, indent_level + 1)},\n"
                    result += f"{indent})"
                    return result
            except:
                pass
            
            # Fallback to pprint's representation
            return pprint.pformat(value)
    
    # Away we go
    return _format_value(context)

def log(message: str, *, context: Any = None) -> None:
    """Log a message with optional context, at DEBUG level."""
    if context is not None:
        message += f"\nContext: {format_context(context)}"
    print(f"[DEBUG] {message}")
    
    
# ==================================================================
# InstallationRecord
# ==================================================================
    
@dataclass
class FileInstallation:
    """Represents the log line from a trunk install command that indicates a file was installed
    
    example:
    [+] extension/bloom.control => /usr/share/postgresql/16/extension
    """

    src: str # ex. extension/bloom.control
    dest: str # ex. /usr/share/postgresql/16/extension
    
    @property
    def belongs_in_pkglibdir(self) -> bool:
        return self.actual_path.is_file() and self.actual_path.suffix in ['.so', '.dylib', '.dll', '.bc']
    
    @property
    def belongs_in_sharedir(self) -> bool: return not self.belongs_in_pkglibdir # only other option
    
    @property
    def dest_dir(self) -> Path: return Path(self.dest) # absolute path
         
    @property
    def src_path(self) -> Path: return Path(self.src) # relative path
    
    @property
    def actual_path(self) -> Path: return self.dest_dir.joinpath(self.src_path) # absolute path
    
    @property
    def actual_str(self) -> str: return str(self.actual_path)
    
    def __repr__(self) -> str:
        return f"InstalledPath(src={self.src}, dest={self.dest})"
    
    @classmethod
    def from_string(cls, line: str) -> Self:
        pattern : re.Pattern  = re.compile(r"\[\+\]\s(.+?)\s=>\s(.+)")
        if match := pattern.match(line):
            src = match.group(1).strip()
            dest = match.group(2).strip()
            return cls(src=src, dest=dest)
        raise ValueError(f"Invalid line format: {line}")
    

@dataclass
class InstallLine:
    """One of the lines of the trunk install output"""
    content: str
    line_number: int # 1-based index
    
    # linked list
    prev: Optional[Self] = None
    next: Optional[Self] = None
    
    def is_error(self) -> bool: return "error:" in self.content
    def is_info(self) -> bool: return "info:" in self.content
    
    def is_file_installation(self) -> bool:
        return self.content.strip().startswith("[+]")
    
    def prev_items(self) -> Generator[Self, None, None]:
        """Generator stopping when self.prev is None"""
        current = self.prev
        while current:
            yield current
            current = current.prev
            
    def next_items(self) -> Generator[Self, None, None]:
        """Generator stopping when self.next is None"""
        current = self.next
        while current:
            yield current
            current = current.next
            
    
    def is_before(self, predicate: Callable[[Self], bool]) -> bool: return any(predicate(item) for item in self.next_items()) 
    def is_after(self, predicate: Callable[[Self], bool]) -> bool: return any(predicate(item) for item in self.prev_items()) 
        
    def is_after_post_installation_steps(self) -> bool:
        return self.is_after(lambda line: "POST INSTALLATION STEPS" in line.content)
    
    def is_before_post_installation_steps(self) -> bool:
        return not self.is_after_post_installation_steps()
    
    def is_after_installed_paths(self) -> bool:
        return self.is_after(lambda line: line.is_file_installation())
                
                

    @property
    def pkglibdir(self) -> Path:
        if not self.is_using_pkglibdir(): raise RuntimeError("Not a pkglibdir line")
        return Path(self.content.split(":")[-1].strip("\" "))
    
    @property
    def sharedir(self) -> Path:
        if not self.is_using_sharedir(): raise RuntimeError("Not a sharedir line")
        return Path(self.content.split(":")[-1].strip("\" "))
    
    @property
    def pg_version(self) -> str:
        if not self.is_using_pg_version(): raise RuntimeError("Not a pg_version line")
        return self.content.split(":")[-1].strip("\" ")
        
    
    def is_empty(self) -> bool: return not self.content.strip()
    
    def is_present(self) -> bool: return not self.is_empty()
    
    def is_using(self) -> bool:
        """
        Using pkglibdir: "/usr/lib/postgresql/16/lib"
        Using sharedir: "/usr/share/postgresql/16/extension"
        Using Postgres version: 16
        """
        return all([
            self.is_present(),
            self.content.startswith("Usage:"),
        ])
        
    def is_using_pkglibdir(self) -> bool:
        return self.content.startswith("Using pkglibdir:")
    
    def is_using_sharedir(self) -> bool:
        return self.content.startswith("Using sharedir:")
    
    def is_using_pg_version(self) -> bool:
        return self.content.startswith("Using Postgres version:")
        
    
    def is_enable_extension_sql(self) -> bool:
        a = self.is_after_post_installation_steps()
        
        return all([
            self.is_after_post_installation_steps(),
            self.is_after(lambda line: "Enable the extension with:" in line.content),
            "CREATE EXTENSION" in self.content,
        ])
        
    
    def is_system_dep_library(self) -> bool:
        """Checks if the line is a system dependency library name"""
        return all([
            self.is_after_post_installation_steps(),
            self.is_after(lambda line: "On systems using" in line.content),
            self.is_present(),
            self.is_before(lambda line: line.is_empty()),
        ])
        
    def is_postgresql_conf_setting(self) -> bool:
        """Checks if the line is a postgresql.conf setting"""
        return all([
            self.is_after_post_installation_steps(),
            self.is_after(lambda line: "Add the following to your postgresql.conf:" in line.content),
            self.is_present(),
            self.is_before(lambda line: line.is_empty()),
        ])
        
    def is_part_of_system_package_manager_logs(self) -> bool:
        """Checks if the line is part of the system package manager logs run when --deps is specified on trunk install.
        [+] extension/bloom.control => /usr/share/postgresql/16/extension    
        Reading package lists...                                             <--- qualify
        Building dependency tree...                                          <--- qualify                         
        Reading state information...                                         <--- qualify
        libc6 is already the newest version (2.36-9+deb12u10).               <--- qualify
        0 upgraded, 0 newly installed, 0 to remove and 0 not upgraded.       <--- qualify
        
        *************************** 
        * POST INSTALLATION STEPS *
        """
        
        
        return all([
            self.is_after_installed_paths(),
            self.is_present(),
            not self.content.startswith("[+]"),
            self.is_before_post_installation_steps(),
        ])
        
    
        

@dataclass
class InstallLines:
    """Data class that parses and organized trunk install output information into a models"""
    
    output: str = ""
    
    lines                    : List[InstallLine] = field(default_factory=list)
    file_installations       : List[FileInstallation] = field(default_factory=list)
    
    _pkglibdir               : Path | None       = None
    _sharedir                : Path | None       = None
    _pg_version              : str | None        = None
    _create_extension_sql    : str | None        = None
    
    system_dep_libraries     : List[str]         = field(default_factory=list)
    postgresql_conf_settings : List[str]         = field(default_factory=list)
    
    def __post_init__(self) -> None:
        """Parses the output string into lines and paths"""
        self.lines = [InstallLine(line, i) for i, line in enumerate(self.output.splitlines())]
        
        # Setup the doubly linked list
        for i in range(len(self.lines) - 1):
            self.lines[i].next = self.lines[i + 1]
            self.lines[i + 1].prev = self.lines[i]
            
        
        for logline in self.lines:
            if logline.is_file_installation():
                self.file_installations.append(FileInstallation.from_string(logline.content))
            
            if logline.is_using_pkglibdir():
                self._pkglibdir = logline.pkglibdir
                continue
            
            if logline.is_using_sharedir():
                self._sharedir = logline.sharedir
                continue
            
            if logline.is_using_pg_version():
                self._pg_version = logline.pg_version
                continue
            
            if logline.is_enable_extension_sql():
                self._create_extension_sql = logline.content.strip()
                break
            
            if logline.is_system_dep_library():
                self.system_dep_libraries.append(logline.content.strip())
                continue
            
            if logline.is_postgresql_conf_setting():
                self.postgresql_conf_settings.append(logline.content.strip())
                continue
        
    @property
    def pkglibdir(self) -> Path:
        if self._pkglibdir is None:
            raise RuntimeError("pkglibdir not populated")
        return self._pkglibdir

    @property
    def sharedir(self) -> Path:
        if self._sharedir is None:
            raise RuntimeError("sharedir not populated")
        return self._sharedir

    @property
    def pg_version(self) -> str:
        if self._pg_version is None:
            raise RuntimeError("pg_version not populated")
        return self._pg_version

    @property
    def create_extension_sql(self) -> str:
        if self._create_extension_sql is None:
            raise RuntimeError("create_extension_sql not populated")
        return self._create_extension_sql
        
        
    @classmethod
    def from_string(cls, output: str) -> Self: 
        return cls(output=output)
        
        



@dataclass
class TrunkInstallResult:
    returncode: int
    stdout: str
    stderr: str
    cmd: str
    args: List[str]
    
    _install_lines: InstallLines | None = field(default=None)
    
    @property
    def install_lines(self) -> InstallLines:
        if self._install_lines is None: 
            self._install_lines = InstallLines.from_string(self.output)
        return self._install_lines
    
    @property
    def extension_name(self) -> str: return self.args[1] # cmd arg0 arg1 => trunk install <extension_name>
    
    @property
    def file_installations(self) -> List[FileInstallation]:
        return self.install_lines.file_installations
    
    @property
    def system_dep_libraries(self) -> List[str]:
        return self.install_lines.system_dep_libraries
    
    @property
    def postgresql_conf_settings(self) -> List[str]:
        return self.install_lines.postgresql_conf_settings
    
    @property
    def pkglibdir(self) -> Path: return self.install_lines.pkglibdir
    
    @property
    def sharedir(self) -> Path : return self.install_lines.sharedir
    
    @property
    def pg_version(self) -> str: return self.install_lines.pg_version
    
    @property
    def output(self) -> str: return self.stdout + "\n" + self.stderr
    
    @classmethod
    def from_completed_process(cls, result: subprocess.CompletedProcess[str]) -> Self:
        return cls( returncode=result.returncode, stdout=result.stdout, stderr=result.stderr, cmd=result.args[0], args=result.args[1:] )
        

@dataclass 
class TrunkInstall:
    """Fluent, library-level interface for configuring and running 'trunk install' for Postgres extensions."""
    extension:    str
    registry:     str | None  = field(default="https://registry.pgtrunk.io")
    pg_version:   str | None  = field(default="16")
    pg_config:    Path | None = field(default_factory=lambda: Path("/usr/lib/postgresql/16/bin/pg_config"))
    pkglibdir:    Path | None = field(default_factory=lambda: Path("/usr/lib/postgresql/16/lib"))
    sharedir:     Path | None = field(default_factory=lambda: Path("/usr/share/postgresql/16/extension"))
    strip_libdir: bool | None = field(default=False)
    install_system_deps: bool | None = field(default=True) 
    skip_deps:    bool | None = field(default=False)
    version:      str | None  = field(default=None)

    _result: TrunkInstallResult | None = field(default=None, init=False, repr=False)

    def with_registry(self, registry: str | None) -> Self: self.registry = registry; return self
    def with_pg_version(self, pg_version: str | None) -> Self: self.pg_version = pg_version; return self
    def with_pg_config(self, pg_config: Union[str, Path]) -> Self: self.pg_config = Path(pg_config); return self
    def with_pkglibdir(self, pkglibdir: Union[str, Path]) -> Self: self.pkglibdir = Path(pkglibdir); return self
    def with_sharedir(self, sharedir: Union[str, Path]) -> Self: self.sharedir = Path(sharedir); return self
    def with_stripped_libdir(self, strip: bool = True) -> Self: self.strip_libdir = strip; return self
    def with_system_deps_installed(self, do_install: bool = True) -> Self: self.install_system_deps = do_install; return self
    def with_skip_deps(self, should_skip: bool = False) -> Self: self.skip_deps = should_skip; return self
    def with_version(self, version: str) -> Self: self.version = version; return self
        
    @property
    def result(self) -> TrunkInstallResult:
        if self._result is None: raise RuntimeError("Command has not been run yet.")
        return self._result

    @property
    def to_dict(self) -> Dict[str, Any]: return asdict(self)
        

    @property
    def cmd(self) -> str: return "/root/.cargo/bin/trunk"
        

    @property
    def args(self) -> List[str]:
        args = [ "install" ]
        
        if self.registry:     args += ["--registry", self.registry]
        if self.pg_version:   args += ["--pg-version", self.pg_version]
        if self.pg_config:    args += ["--pg-config", str(self.pg_config)]
        if self.pkglibdir:    args += ["--pkglibdir", str(self.pkglibdir)]
        if self.sharedir:     args += ["--sharedir", str(self.sharedir)]
        if self.version:      args += ["--version", self.version]
        
        if self.strip_libdir: args.append("--strip-libdir")
        if self.install_system_deps: args.append("--deps")
        if self.skip_deps: args.append("--skip-dependencies")
        
        args.append(self.extension)
        
        return args
    
    

    def run(self, *extra_args: str, cwd: Path | None = None, env: Dict[str, str] | None = None) -> Self:
        """Blocks until the command completes. Returns self."""
        if cwd is None: cwd = Path.cwd()
        if env is None: env = {}
        
        cmd = self.cmd
        args = self.args + list(extra_args)
        
        # Run the command
        try:
            result = subprocess.run([cmd] + args, cwd=cwd, env=env, capture_output=True, text=True)
            self._result = TrunkInstallResult.from_completed_process(result)
            self.after_run()
            return self
        except Exception as e:
            raise RuntimeError(f"Failed to run command: {cmd} {' '.join(args)} \n{e}") from e
    
    def issue_handlers(self) -> List["IssueHandler"]:
        """Returns a list of issue handlers to run after the command completes"""
        return [
            OutdatedDependencyIssueHandler(self.result),
            NonCompliantExtensionPathIssueHandler(self.result),
        ]
    
    def after_run(self) -> Self:
        """Check for issues and resolve them if needed"""
        for handler in self.issue_handlers():
            if handler.predicate():
                handler.resolve()
        return self
        
        
        
        


@contextmanager
def apt_get_updated() -> Generator[None, None, None]:
    """Context manager to ensure apt-get update is run at most once per 60 seconds.
    
    with apt_get_updated():
        # Your code here
    
    
    """

    lock_path = "/tmp/apt-get-update.lock"
    now = time.time()
    min_interval = 60  # seconds

    # Open or create the lock file
    with open(lock_path, "a+") as lock_file:
        # Acquire exclusive lock
        fcntl.flock(lock_file, fcntl.LOCK_EX)
        lock_file.seek(0)
        try:
            last_run = float(lock_file.read().strip())
        except Exception:
            last_run = 0.0

        if now - last_run > min_interval:
            subprocess.run(["apt-get", "update"], check=True)
            lock_file.seek(0)
            lock_file.truncate()
            lock_file.write(str(now))
            lock_file.flush()
        
        yield None  # yield control to the caller
        
        # Lock releases automatically when exiting the context manager

def apt_get_install(*packages: str) -> None:
    """Install each package individually, running update if needed."""
    with apt_get_updated():
        for pkg in packages:
            subprocess.run(["apt-get", "install", "-y", pkg], check=True)
        
    
    

@dataclass
class IssueHandler(ABC):
    """Detects and Fixes issues based on TrunkInstallResult"""
    result: TrunkInstallResult
    
    @abstractmethod
    def predicate(self) -> bool:
        """Detects if the issue is present in the result"""
        pass
    
    @abstractmethod
    def resolve(self) -> None:
        """Fixes / implements a solution for the issue"""
        pass
    
    
class OutdatedDependencyIssueHandler(IssueHandler):
    """Correct the installation of failed outdated dependencies references. """
    
    # Simple conversion map for known issues
    MAP = {
        "libpython3": "libpython3.11-dev",
        "libproj22": "libproj-dev",
        "libc6": "libc6-dev",
    }
    
    def libraries_to_install(self) -> Generator[str, None, None]:
        for libname in self.result.system_dep_libraries:
            if libname in self.MAP:
                yield self.MAP[libname]

    def predicate(self) -> bool:
        """Checks for a known outdated dependency reference in the install logs"""
        return any(self.libraries_to_install())

    def resolve(self) -> None:
        """Ensure the correct dependencies are installed using apt-get."""
        distinct_libs = list(set(self.libraries_to_install()))
        apt_get_install(*distinct_libs)
    
@dataclass
class PotentiallyIncorrectlyInstalledPath:
    """Paths that are incorrectly installed in the wrong directory"""

    pkglibdir_path: Path # of the expected path
    sharedir_path: Path # of the expected path
    
    file_installation: FileInstallation # the actual path
    
    @property
    def actual_path_str(self) -> str: return self.file_installation.actual_str
    
    @property
    def actual_source_rel_path_string(self) -> str: return self.file_installation.src
    
    @property
    def expected_base_path(self) -> Path: return self.pkglibdir_path if self.file_installation.belongs_in_pkglibdir else self.sharedir_path
    
    @property
    def expected_path_str(self) -> str:
        """Returns the expected path based on the installed_path's type and crucially the path.source_rel_path from the install logs"""
        expected_base_path = self.expected_base_path
        actual_source_rel_path = self.actual_source_rel_path_string
            
        proposed_expected_path = Path(expected_base_path.as_posix().rstrip("/") + "/" + actual_source_rel_path.lstrip("/"))
            
        # Corrective placement fix
        # in come cases the actual_source_rel_path will have an extra `extension` prefix path
        # ex: [+] extension/vector.control => /share/postgresql/16/extension
        #         |                                                |
        #         |> Extra "extension" prefix                      |> Destination path
        #         |________________________._______________________|
        #                                  |
        #                                  |-> /share/postgresql/16/extension/extension/vector.control 
        # as you can see we have a double "extension" prefix, thus this script will move anything under the double "extension" prefix to 
        # a path with only one "extension" prefix, as the "expected_path"
        if "extension/extension/" in proposed_expected_path.as_posix():
            proposed_expected_path = Path(proposed_expected_path.as_posix().replace("extension/extension/", "extension/"))
        
        return proposed_expected_path.as_posix()
    
    @property
    def actual_path(self) -> Path: return Path(self.actual_path_str)
         
    @property
    def expected_path(self) -> Path: return Path(self.expected_path_str)
            
            
    @property
    def is_definitely_incorrect(self) -> bool:
        return self.expected_path_str != self.actual_path_str

COLOR_TO_EMOJI_CIRCLE = {
    "red": "🔴",
    "orange": "🟠",
    "yellow": "🟡",
    "green": "🟢",
    "blue": "🔵",
    "purple": "🟣",
    "brown": "🟤",
    "black": "⚫",
    "white": "⚪",
}        

AllowedColors = Literal["red", "orange", "yellow", "green", "blue", "purple", "brown", "black", "white"]

class Status:
    """passed to yield to allow for color and status rendering on the current line"""
    def __init__(self, message: str, color: AllowedColors | None = None) -> None:
        self._message : str = message
        self._color : AllowedColors | None = color
        self._current_line : str = ""
    
    @property
    def emoji(self) -> str | None:
        """Returns the emoji circle for the color, or None if no color is set"""
        if self._color is None: return None
        return COLOR_TO_EMOJI_CIRCLE[self._color]
    
    def with_color(self, color: AllowedColors) -> Self:
        self.color = color
        return self
    
    def with_message(self, message: str) -> Self:
        self.message = message
        return self
    
    @property
    def color(self) -> AllowedColors | None: return self._color
    
    @color.setter
    def color(self, color: AllowedColors) -> None:
        self._color = color
        self.render()
    
    @property
    def message(self) -> str: return self._message
    
    @message.setter
    def message(self, message: str) -> None:
        self._message = message
        self.render()
    
    def render(self):
        new_line = ""
        if self._color is not None:
            new_line += f"{self.emoji} "
        new_line += f"{self._message}"
        
        current_line = self._current_line
        
        length_to_right_pad = len(new_line) - len(current_line)
        if length_to_right_pad > 0:
            current_line += " " * length_to_right_pad
        # else the new line will overwrite the old line
        
        # update the current line
        self._current_line = new_line
        
        # Update the current line in the terminal
        print(f"\r{current_line}", end="")
        

@contextmanager
def status(message: str, color: AllowedColors | None = None) -> Generator[Status, None, None]:
    status = Status(message, color)
    status.render()
    yield status
    print("")  # Move to the next line after the status is done 
        
class NonCompliantExtensionPathIssueHandler(IssueHandler):
    """Correct cases where the --pkglibdir and/or --sharedir are not used correctly repsected"""

        
    
    def potentially_incorrect_paths(self) -> List[PotentiallyIncorrectlyInstalledPath]:
        """Returns a list of paths that are potentially incorrectly installed"""
        pkglibdir = self.result.pkglibdir
        sharedir = self.result.sharedir
        
        installed_paths = self.result.file_installations
        
        return [
            PotentiallyIncorrectlyInstalledPath( pkglibdir_path=pkglibdir, sharedir_path=sharedir, file_installation=path) 
            for path in installed_paths
        ]
            
    def definitely_incorrect_paths(self) -> List[PotentiallyIncorrectlyInstalledPath]:
        return [path for path in self.potentially_incorrect_paths() if path.is_definitely_incorrect]
    
    
    def predicate(self) -> bool:
        """We need to check if the actual_* path of an installed file respected the --pkglibdir and/or --sharedir depending on its type"""
        with status(f"🟡 Checking for incorrect paths...") as ctrl:
            for pi_path in self.potentially_incorrect_paths():
                if pi_path.is_definitely_incorrect:
                    return True
            ctrl.with_color("green").with_message(f"No incorrect paths found")
        return False
    
    def resolve(self) -> None:
        """Ensure the pkglibdir and sharedir are used correctly by moving files to their correct locations"""
        incorrect_paths = self.definitely_incorrect_paths()
        
        log(f"[🔴] Found a total of {len(incorrect_paths)} incorrect paths")
        
        
        
        
        for pi_path in incorrect_paths:
            with status(f"Resolving: {pi_path.actual_path} -> {pi_path.expected_path}", color="yellow") as ctrl:
            
                expected_path = pi_path.expected_path
                actual_path = pi_path.actual_path
                
                # Ensure the destination directory exists
                expected_path.parent.mkdir(parents=True, exist_ok=True)
                
                if not actual_path.exists(): 
                    ctrl.with_color("red").with_message(f"Actual path does not exist: {actual_path}")
                    raise RuntimeError(f"The 'actual path' of the installed file does not exist: {actual_path}")
                
                # Remove the existing file path if it already exists
                if expected_path.exists(): expected_path.unlink() 
                
                # Move actual -> expected
                actual_path.rename(expected_path)
                
                if expected_path.exists():
                    ctrl.with_color("green").with_message(f"Moved {actual_path} to {expected_path}")
        

# TODO: postgresql.conf settings auto added
# TODO: enablement sql auto added as init scripts

@click.command()
@click.argument("extension", type=str)
@click.option("-p", "--pg-config", type=str, default="/usr/lib/postgresql/16/bin/pg_config", help="Path to the pg_config executable")
@click.option("-v", "--version", type=str, default="latest", help="Version of the extension to install")
@click.option("-r", "--registry", type=str, default="https://registry.pgtrunk.io", help="Trunk registry URL")
@click.option("--pg-version", type=str, default="16", help="PostgreSQL version for which this extension should be installed")
@click.option("-s", "--skip-dependencies", is_flag=True, default=False, help="Skip dependency resolution") 
@click.option("--deps", is_flag=True, default=True, help="Install required system dependencies for the extension")
@click.option("--sharedir", type=str, default="/usr/share/postgresql/16", help="Installation location for architecture-independent support files")
@click.option("--pkglibdir", type=str, default="/usr/lib/postgresql/16/lib", help="Installation location for dynamically loadable modules")
@click.option("--strip-libdir", is_flag=True, default=False, help="Strip $libdir/ from module_pathname before installing control file")
def trunk_install(
    extension: str,
    pg_config: str,
    version: str,
    registry: str,
    pg_version: str,
    skip_dependencies: bool,
    deps: bool,
    sharedir: str,
    pkglibdir: str,
    strip_libdir: bool
) -> None:
    """Install a Postgres extension from the Trunk registry with corrected installation parts"""
    
    trunk_install = (TrunkInstall(extension)
        .with_pg_config(pg_config)
        .with_pkglibdir(pkglibdir)
        .with_sharedir(sharedir)
        .with_pg_version(pg_version)
        .with_registry(registry)
        .with_stripped_libdir(strip_libdir)
        .with_system_deps_installed(deps)
        .with_skip_deps(not skip_dependencies) # invert as the meaning is opposite on the TrunkIntall class "with"
        .with_version(version)
    )
    
    # Run the command
    trunk_install.run()
    


def main() -> None:
    """Run click command"""
    trunk_install()

if __name__ == "__main__":
    main()
