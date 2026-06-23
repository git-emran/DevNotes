# Building an APP with Quart

## Quart needs an env file to run if managed with just venv

```bash

QUART_APP=run 
QUART_ENV=development

```

## When venv doesnt get recognized by lsp(pyright), its convenient to just do this in `pyrightconfig.json`

```json

{
  "venvPath": ".",
  "venv": ".venv"
}
```

## Sometimes pytest cant find modules because a folder is not in the python path. In that case add in the `pyproject.toml` add the following so that pytest can recognize the path

```toml

[tool.pytest.ini_options]
pythonpath = ["."]

```