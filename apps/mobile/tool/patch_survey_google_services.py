"""Add the Circuito 8h package to google-services.json so the survey flavor builds.

The file is secret and lists com.rawthrottle.riderlab. The side app id is
com.rawthrottle.riderlab.c8h. This clones the existing Android client entry.
"""

import json
import sys

PACKAGE = "com.rawthrottle.riderlab.c8h"
SOURCE = "com.rawthrottle.riderlab"


def package_name(client):
    return (
        client.get("client_info", {})
        .get("android_client_info", {})
        .get("package_name")
    )


def main(path):
    with open(path) as fh:
        data = json.load(fh)
    clients = data.get("client") or []
    if any(package_name(c) == PACKAGE for c in clients):
        return
    base = next((c for c in clients if package_name(c) == SOURCE), None)
    if base is None and clients:
        base = clients[0]
    if base is None:
        raise SystemExit("google-services.json has no Android client")
    side = json.loads(json.dumps(base))
    side["client_info"]["android_client_info"]["package_name"] = PACKAGE
    clients.append(side)
    data["client"] = clients
    with open(path, "w") as fh:
        json.dump(data, fh)


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "android/app/google-services.json")
