import os
import glob
import random
import string
import re
from github import Github
from git import Repo
from git import Actor


class ActionInputs:
    def __init__(self):
        self.author = os.environ.get(
            "INPUT_AUTHOR",
            "Github Actions <github-actions[bot]@@users.noreply.github.com>",
        )
        self.committer = os.environ.get(
            "INPUT_COMMITTER",
            "Github Actions <github-actions[bot]@@users.noreply.github.com>",
        )
        self.branch_name = os.environ.get("INPUT_BRANCH_NAME", "patch")
        self.base_branch = os.environ.get("INPUT_BASE_BRANCH", "main")
        self.commit_message = os.environ.get(
            "INPUT_COMMIT_MESSAGE", "chore: automated by github actions"
        )
        self.token = os.environ.get("INPUT_TOKEN")

        if not self.token:
            raise Exception("GitHub token not found")


class ActionOutputs:
    output_file_path = "/tmp/action_outputs.txt"

    def __init__(self):
        self.created = False
        self.number = None
        self.url = None

    def write(self):
        with open(self.output_file_path, "w") as file:
            if self.created and self.number and self.url:
                file.write(f"pull-request-created={str(self.created).lower()}\n")
                file.write(f"pull-request-number={self.number}\n")
                file.write(f"pull-request-url={self.url}\n")


def extract_repo_path(url):
    pattern = r"(?:https?://github\.com/|github\.com:)([^/]+/[^/.]+)"
    match = re.search(pattern, url)
    if match:
        return match.group(1)
    return None


def create_pull_request(inputs: ActionInputs):
    # Generate a random string of 6 characters
    random_suffix = "".join(random.choices(string.ascii_lowercase + string.digits, k=6))

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

    # Create a new branch
    new_branch_name = f"bot/{inputs.branch_name}-{random_suffix}"
    new_branch = repo.create_head(new_branch_name)
    new_branch.checkout()

    # Add files matching the pattern
    files_to_add = glob.glob("*")
    entries = repo.index.add(files_to_add)

    print(f"Added {len(entries)} files to index.")
    print(f"Files added: {entries}")

    # if len(entries) == 0:
    print("There are no changes to commit.")
    outputs.write()
    # return

    # Commit changes
    # repo.index.commit(
    #     inputs.commit_message,
    #     parent_commits=None,
    #     head=True,
    #     author=Actor._from_string(inputs.author),
    #     committer=Actor._from_string(inputs.committer),
    # )

    # # Push the changes to the remote repository
    # origin = repo.remote(name="origin")
    # origin.push(new_branch)

    # # Create a pull request
    # pull_request = github_repo.create_pull(
    #     title=inputs.commit_message,
    #     body="Automatically created by Github Actions",
    #     base=inputs.base_branch,
    #     head=new_branch_name,
    # )
    # pull_request.add_to_labels("auto-pr")

    # # Adds information to action output
    # outputs.created = True
    # outputs.number = pull_request.number
    # outputs.url = pull_request.url

    # print(f"New branch '{new_branch_name}' created, files added, and pushed to remote.")
    # outputs.write()


if __name__ == "__main__":
    inputs = ActionInputs()
    create_pull_request(inputs)
