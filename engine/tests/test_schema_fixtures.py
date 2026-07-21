from pathlib import Path
import json
import jsonschema

ROOT = Path(__file__).parents[2]

def test_all_protocol_fixtures_validate() -> None:
    schema = json.loads((ROOT / "schemas/engine_protocol_v1.schema.json").read_text("utf-8"))
    for fixture in (ROOT / "schemas/fixtures").glob("*.json"):
        jsonschema.validate(json.loads(fixture.read_text("utf-8")), schema)

def test_every_fixture_declares_schema_version_one() -> None:
    for fixture in (ROOT / "schemas/fixtures").glob("*.json"):
        assert json.loads(fixture.read_text("utf-8"))["schema_version"] == 1
