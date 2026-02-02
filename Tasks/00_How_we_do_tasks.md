# Task Management Workflow

We follow a file-based task management system to keep track of our progress.

## Directory Structure

*   **`Tasks/in_progress/`**: Contains markdown files for tasks currently being worked on.
*   **`Tasks/completed/`**: Contains markdown files for tasks that have been finished.
*   **`Tasks/Notes/`**: General project notes, ideas, and documentation not tied to specific immediate tasks.

## Workflow

1.  **Define a Task**:
    *   Create a new markdown file in `Tasks/in_progress/` with a descriptive name (e.g., `01-setup-basic-structure.md`).
    *   Create a new feature branch (e.g., `git checkout -b feature/task-name`).
2.  **Document**: Inside the task file, outline the objective, requirements, and checklist of items to complete.
3.  **Execute**:
    *   As you work, check off items and add notes if the plan changes.
    *   Commit changes to the feature branch regularly.
4.  **Complete**: Once satisfied, move the file from `Tasks/in_progress/` to `Tasks/completed/` and commit the change.
5.  **Merge**:
    *   Wait for approval (if working with a reviewer).
    *   Checkout `main` (`git checkout main`).
    *   Merge the feature branch (`git merge feature/task-name`).
    *   Delete the feature branch (`git branch -d feature/task-name`).

## Coding Standards

*   **One Struct/Function Per File**: We adhere to a strict policy of one struct or function per file unless absolutely needed otherwise.

## Clood Files (Code Domains)

We use "clood files" to track code domains helping us maintain context of related files.

*   **Definition**: A clood file is a JSON file that tracks all files related to a specific code domain.
*   **Location**:Stored in the `clood-groups/` folder.
*   **Usage Rule**: When a task is worked on, you MUST update or create a clood file related to the domain you worked on.
    *   This helps assist future tasks.
    *   Overlap between groups is ok.
    *   It should basically be a list of file paths that are relevant to that specific "clood" or domain.
