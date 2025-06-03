#!/bin/sh
# Exit immediately if a command exits with a non-zero status.
set -e

# Determine Python command (try python3, then python)
PYTHON_CMD=python3
if ! command -v $PYTHON_CMD >/dev/null 2>&1; then
    PYTHON_CMD=python
fi

# Ensure Python command was found
if ! command -v $PYTHON_CMD >/dev/null 2>&1; then
    echo "SWE-agent: install.sh - Python interpreter (python3 or python) not found. Cannot proceed."
    exit 1
fi

# Check if pip is available (as a Python module); if not, try to install it
if ! $PYTHON_CMD -m pip --version >/dev/null 2>&1; then
  echo "SWE-agent: install.sh - pip module not found for $PYTHON_CMD. Attempting to install pip..."
  # Try to download and run get-pip.py using curl or wget
  # Piping directly to python avoids needing to save and then delete get-pip.py
  if command -v curl >/dev/null 2>&1; then
    curl -sS https://bootstrap.pypa.io/get-pip.py | $PYTHON_CMD
  elif command -v wget >/dev/null 2>&1; then
    wget -qO- https://bootstrap.pypa.io/get-pip.py | $PYTHON_CMD
  else
    echo "SWE-agent: install.sh - Error: curl or wget not found. Cannot download get-pip.py to install pip."
    exit 1
  fi
  echo "SWE-agent: install.sh - pip installation attempted."
fi

# Install the required packages using python -m pip for robustness
echo "SWE-agent: install.sh - Installing tree-sitter packages..."
$PYTHON_CMD -m pip install --no-cache-dir 'tree-sitter==0.21.3'
$PYTHON_CMD -m pip install --no-cache-dir 'tree-sitter-languages'

echo "SWE-agent: install.sh - Script finished."