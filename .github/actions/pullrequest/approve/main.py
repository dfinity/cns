import os
import re
import requests
from github import Github
from git import Repo


class ActionInputs:
    def __init__(self):
        self.should_auto_merge = parse_env_bool("INPUT_AUTO_MERGE", False)
        self.pull_request_number = int(os.environ.get("INPUT_PULL_REQUEST_NUMBER"))
        self.token = os.environ.get("INPUT_TOKEN")

        if not self.token:
            raise Exception("GitHub token not found")

        if not self.pull_request_number:
            raise Exception("Pull request number not found")


class ActionOutputs:
    output_file_path = "/tmp/action_outputs.txt"

    def __init__(self):
        self.approved = False

    def write(self):
        with open(self.output_file_path, "w") as file:
            file.write(f"pull-request-approved={str(self.approved).lower()}\n")


def parse_env_bool(env_var_name, default=False):
    value = os.environ.get(env_var_name)
    if value is None:
        return default
    return value.lower() == "true" or value == "1"


def extract_repo_path(url):
    pattern = r"(?:https?://github\.com/|github\.com:)([^/]+/[^/.]+)"
    match = re.search(pattern, url)
    if match:
        return match.group(1)
    return None


def extract_repo_details(repo_name):
    pattern = r"([^/]+)/([^/]+)"
    match = re.match(pattern, repo_name)

    if match:
        return match.groups()
    else:
        raise ValueError("Invalid input format: Expected 'owner/repo'.")


def fetch_pull_request_node_id(owner, name, pr_number, authorization_token):
    query = """
        query FindPullRequestNodeId {{
            repository(name: "{repo_name}", owner: "{repo_owner}") {{
                pullRequest(number: {pr_number}) {{
                    id
                }}
            }}
        }}
    """.format(
        repo_name=name, repo_owner=owner, pr_number=pr_number
    )

    request = requests.post(
        "https://api.github.com/graphql",
        json={"query": query},
        headers={"Authorization": "Bearer {}".format(authorization_token)},
    )

    if request.status_code == 200:
        result = request.json()
        return result["data"]["repository"]["pullRequest"]["id"]
    else:
        raise Exception(
            "Query failed to run by returning code of {}. {}".format(
                request.status_code, query
            )
        )


def enable_pull_request_auto_merge(pull_request_node_id, authorization_token):
    mutation = """
        mutation EnablePullRequestAutoMerge {{
            enablePullRequestAutoMerge(input: {{pullRequestId: "{node_id}"}}) {{
                pullRequest {{
                    id
                    merged
                }}
            }}
        }}
    """.format(
        node_id=pull_request_node_id
    )
    request = requests.post(
        "https://api.github.com/graphql",
        json={"query": mutation},
        headers={"Authorization": "Bearer {}".format(authorization_token)},
    )
    if request.status_code != 200:
        raise Exception(
            "Mutation failed to run by returning code of {}. {}".format(
                request.status_code, mutation
            )
        )


def approve_pull_request(inputs: ActionInputs):
    # Init action outputs
    outputs = ActionOutputs()

    # github_client = Github(inputs.token)
    repo = Repo(".")
    remote_repo_url = repo.remotes[0].config_reader.get("url")
    remote_repo_path = extract_repo_path(remote_repo_url)

    if not remote_repo_path:
        raise Exception("Could not find remote repository URL")

    # Find the repository node_id
    owner, repository_name = extract_repo_details(remote_repo_path)
    pull_request_node_id = fetch_pull_request_node_id(
        owner, repository_name, inputs.pull_request_number, inputs.token
    )

    # Get the Github repository
    github_client = Github(inputs.token)
    github_repo = github_client.get_repo(remote_repo_path)

    # Approve the pull request
    pull_request = github_repo.get_pull(inputs.pull_request_number)
    pull_request.create_review(event="APPROVE")

    if inputs.should_auto_merge:
        pull_request.add_to_labels("auto-merge")
        enable_pull_request_auto_merge(pull_request_node_id, inputs.token)

    # Adds information to action output
    outputs.approved = True

    print(f"Pull request was approved")
    outputs.write()


if __name__ == "__main__":
    inputs = ActionInputs()
    approve_pull_request(inputs)
