"""Run the Lua logic tests under Lua 5.1 (pip install lupa)."""
import sys
from lupa.lua51 import LuaRuntime

lua = LuaRuntime(unpack_returned_tuples=True)
try:
    lua.execute(open("tests/test_logic.lua").read())
except Exception as e:  # noqa
    print(e)
    sys.exit(1)
