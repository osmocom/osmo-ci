import re
from pathlib import Path


def test_gerrit_verifications_binpkgs():
    """Ensure we don't use more parameters for pipeline_binpkgs than the
    pipeline can handle."""
    yml = Path(Path(__file__) / "../../jobs/gerrit-verifications.yml").resolve()
    regex = re.compile(r'.*pipeline_binpkgs:.*"(.*)"')

    with open(yml) as f:
        num = 0
        for line in f:
            num += 1

            if "pipeline_binpkgs:" not in line:
                continue

            prefix = f"\n\njobs/gerrit_verifications.yml:{num}: {line}\nERROR"

            match = regex.match(line)
            assert match, f"{prefix}: failed to read pipeline_binpkgs"

            count = len(match.group(1).split(" "))
            count_max = 5
            assert count < count_max, (
                f"{prefix}: found {count} parameters, but max is currently {count_max}!"
                " Adjust the 'dsl' section in the yml file and count_max in this test."
            )
