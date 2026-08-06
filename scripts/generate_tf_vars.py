#!/usr/bin/env python3

"""
Convert Terraform JSON outputs into Ansible group_vars/all.yml

Input:
    terraform/outputs.json

Output:
    group_vars/all.yml
"""

import json
from pathlib import Path
import yaml


BASE_DIR = Path(__file__).resolve().parent.parent


INPUT_FILE = (
    BASE_DIR
    / "terraform"
    / "outputs.json"
)


OUTPUT_FILE = (
    BASE_DIR
    / "inventory"
    / "group_vars"
    / "all.yml"
)


def load_outputs():

    with open(INPUT_FILE, "r") as f:
        return json.load(f)



def flatten(terraform_outputs):

    result = {}

    for key, value in terraform_outputs.items():

        if isinstance(value, dict) and "value" in value:
            result[key] = value["value"]

        else:
            result[key] = value

    return result



def write_yaml(data):

    OUTPUT_FILE.parent.mkdir(
        parents=True,
        exist_ok=True
    )


    with open(OUTPUT_FILE, "w") as f:

        f.write(
            "# -------------------------------------------------------------------\n"
        )

        f.write(
            "# AUTO GENERATED FILE\n"
        )

        f.write(
            "# DO NOT EDIT MANUALLY\n"
        )

        f.write(
            "# Generated from terraform/outputs.json\n"
        )

        f.write(
            "# -------------------------------------------------------------------\n\n"
        )


        yaml.safe_dump(
            data,
            f,
            sort_keys=False,
            default_flow_style=False,
        )



def main():

    outputs = load_outputs()

    flat = flatten(outputs)

    write_yaml(flat)

    print(
        f"Generated: {OUTPUT_FILE}"
    )



if __name__ == "__main__":

    main()