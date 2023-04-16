import requests
import argparse
import os
from requests.auth import HTTPBasicAuth
from secrets import token_hex


def create_agent_pool(
    organization_url,
    personal_access_token,
    agent_pool_name=f"Pool-{token_hex(4)}",
    api_version=7.0,
):
    headers = {
        "Content-Type": "application/json",
        "Accept": f"application/json; api-version={api_version}",
    }
    auth = HTTPBasicAuth("", personal_access_token)

    # Create the agent pool
    create_agent_pool_url = (
        f"{organization_url}/_apis/distributedtask/pools?api-version={api_version}"
    )
    payload = {
        "name": agent_pool_name,
        "poolType": "automation",
        "autoProvision": True,
        "autoSize": True,
        "isHosted": False,
        "options": "elasticPool",
    }


    response = requests.post(
        create_agent_pool_url, headers=headers, auth=auth, json=payload, timeout=5
    )
    response.raise_for_status()
    agent_pool = response.json()

    # Print the ID of the created agent pool
    print(
        f"Created Elastic Agent Pool ID: {agent_pool['id']}, Name: {agent_pool['name']}"
    )
    return agent_pool


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Setup Azure DevOps instance")
    parser.add_argument(
        "--pat-token",
        type=str,
        default=os.environ["AZDO_PAT"],
        help="The PAT token for basic auth to Azure DevOps",
    )
    parser.add_argument(
        "--url",
        type=str,
        default=os.environ["AZDO_URL"],
        help="The URL to your Azure DevOps instance",
    )
    parser.add_argument(
        "--log-level",
        type=str,
        default="WARNING",
        help="The level of logging, can be WARNING, DEBUG, INFO etc",
    )
    parser.add_argument(
        "--agent-pool-name",
        type=str,
        default=f"Pool-{token_hex(4)}",
        help="The name for the new agent pool",
    )

    args = parser.parse_args()

    personal_access_token = args.pat_token
    organization_url = args.url
    agent_pool_name = args.agent_pool_name
    new_agent_pool = create_agent_pool(
        personal_access_token=personal_access_token, organization_url=organization_url
    )
    print(new_agent_pool["id"])
