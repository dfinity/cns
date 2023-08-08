import os
import re
from github import Github
from git import Repo


class ActionInputs:
    def __init__(self):
        self.should_merge = parse_env_bool("INPUT_MERGE", False)
        self.pull_request_number = os.environ.get("INPUT_PULL_REQUEST_NUMBER")
        self.token = os.environ.get("INPUT_TOKEN")

        if not self.token:
            raise Exception("GitHub token not found")

        if not self.pull_request_number:
            raise Exception("Pull request number not found")


class ActionOutputs:
    def __init__(self):
        self.approved = 0
        self.merged = 0

    def print(self):
        print(f"::set-output name=approved::{self.approved}")
        print(f"::set-output name=merged::{self.merged}")


def parse_env_bool(env_var_name, default=False):
    value = os.environ.get(env_var_name)
    if value is None:
        return default
    return value.lower() == "true" | value == "1"


def extract_repo_path(url):
    pattern = r"(?:https?://github\.com/|github\.com:)([^/]+/[^/.]+)"
    match = re.search(pattern, url)
    if match:
        return match.group(1)
    return None


def approve_pull_request(inputs: ActionInputs):
    # Init action outputs
    outputs = ActionOutputs()

    # github_client = Github(inputs.token)
    repo = Repo(".")
    remote_repo_url = repo.remotes[0].config_reader.get("url")
    remote_repo_path = extract_repo_path(remote_repo_url)

    if not remote_repo_path:
        raise Exception("Could not find remote repository URL")

    # Get the Github repository
    github_client = Github(inputs.token)
    github_repo = github_client.get_repo(remote_repo_path)

    # Approve the pull request
    pull_request = github_repo.get_pull(inputs.pull_request_number)
    pull_request.add_to_labels("auto-merge")
    pull_request.create_review(event="APPROVE")

    if inputs.should_merge:
        pull_request.merge(merge_method="squash")
        outputs.merged = 1

    # Adds information to action output
    outputs.approved = 1

    print(f"Pull request was approved")
    outputs.print()


if __name__ == "__main__":
    inputs = ActionInputs()
    approve_pull_request(inputs)
