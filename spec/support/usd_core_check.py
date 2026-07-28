#!/usr/bin/env python3
"""Exercise the official OpenUSD APIs shipped in the usd-core wheel.

PyPI's usd-core wheel does not contain the usdchecker and usdcat executables.
This small CI adapter uses the same validation framework as usdchecker and the
same Sdf parser as usdcat.
"""

import argparse
import sys

from pxr import Sdf, Usd, UsdValidation


ROOT_PACKAGE_VALIDATOR = "usdUtilsValidators:RootPackageValidator"


def parse_layer(path):
    layer = Sdf.Layer.FindOrOpen(path)
    if layer is None:
        print(f"Failed to parse layer: {path}", file=sys.stderr)
        return 1
    return 0


def validate_stage(path):
    stage = Usd.Stage.Open(path)
    if stage is None:
        print(f"Failed to open stage: {path}", file=sys.stderr)
        return 1

    registry = UsdValidation.ValidationRegistry()
    names = [
        metadata.name
        for metadata in registry.GetAllValidatorMetadata()
        if not metadata.isSuite and str(metadata.name) != ROOT_PACKAGE_VALIDATOR
    ]
    validators = registry.GetOrLoadValidatorsByName(names)
    context = UsdValidation.ValidationContext(validators)
    errors = context.Validate(stage)

    failed = False
    for error in errors:
        print(error.GetErrorAsString())
        if error.GetType() == UsdValidation.ValidationErrorType.Error:
            failed = True

    if failed:
        print("Failed!", file=sys.stderr)
        return 1

    print("Success!")
    return 0


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("operation", choices=("parse", "validate"))
    parser.add_argument("paths", nargs="+")
    args = parser.parse_args()

    operation = parse_layer if args.operation == "parse" else validate_stage
    return max(operation(path) for path in args.paths)


if __name__ == "__main__":
    sys.exit(main())
