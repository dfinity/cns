import os
import glob
import random
import string
from github import Github
from git import Repo


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


def create_pull_request(inputs: ActionInputs):
    # Generate a random string of 6 characters
    random_suffix = "".join(random.choices(string.ascii_lowercase + string.digits, k=6))

    # github_client = Github(inputs.token)
    repo = Repo("../../../..")
    new_branch_name = f"bot/{inputs.branch_name}-{random_suffix}"
    new_branch = repo.create_head(new_branch_name, repo.active_branch)
    new_branch.checkout()

    # Add files matching the pattern
    files_to_add = glob.glob("*")
    repo.index.add(files_to_add)

    # Commit changes
    repo.index.commit(
        inputs.commit_messag,
        parent_commits=None,
        head=True,
        author=inputs.author,
        committer=inputs.committer,
    )

    # Push the changes to the remote repository
    # origin = repo.remote(name="origin")
    # origin.push(new_branch)

    # pr_created = 0
    # pr_number = None
    # pr_url = None

    print(f"New branch '{new_branch_name}' created, files added, and pushed to remote.")
    # print(f"::set-output name=created::{pr_created}")
    # print(f"::set-output name=number::{pr_number}")
    # print(f"::set-output name=url::{pr_url}")


if __name__ == "__main__":
    inputs = ActionInputs()
    create_pull_request(inputs)
