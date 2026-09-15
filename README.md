# 🚀 Gemini AI CLI & Docker MCP Gateway: The Easy Way

Have you ever wanted a powerful AI assistant that runs right in your terminal, has access to your local files, and can securely connect to external tools like **GitHub**, **Jira**, and **Confluence**—all without installing complex runtime environments (like Node.js or Python) on your computer?

This project does exactly that! It bundles the **Gemini CLI** and the **Docker MCP (Model Context Protocol) Gateway** into a single, highly-secured, pre-configured **Docker Container**.

Think of it as a portable "sandbox" for a smart AI assistant that can:
- 📂 Read and edit files in your local workspace folder.
- 💬 Connect to your developer platforms (GitHub, Jira, Confluence, etc.) to fetch or update tasks.
- 🔒 Run with state-of-the-art security, keeping your passwords, keys, and system perfectly safe.

---

## 🧩 Core Concepts

Before getting started, here are three simple concepts to understand:

1. **The Workspace Folder (`~/gemini/workspace`)**
   This is a folder on your computer where you put code, notes, or files. The AI assistant can see and modify files inside this folder, but it *cannot* touch the rest of your computer.
2. **The Tools File (`profile.yaml`)**
   A file that lists the "skills" (MCP servers) your AI is allowed to use—such as connecting to GitHub or Atlassian tools (Jira & Confluence).
3. **The Secrets File (`profile.env`)**
   A safe place to paste your private API keys or passwords. The Docker app reads these keys securely to talk to GitHub, Jira, etc., and never stores them inside the container image.

---

## 🏃‍♂️ Quick Start Guide (Step-by-Step)

Follow these steps to run your gemini-cli assistant:

### Step 1: Install Prerequisites
You will need to install and start Docker Desktop, then enable the Docker MCP Toolkit. Confirm that Docker and the MCP Toolkit are available before building or running this application:

```bash
docker version
docker mcp version
```

### Step 2: Create/Export Your MCP Profile
Use the Docker MCP Toolkit to create your configuration file, then export it to use with this app. Use this example to export the **Dev workflow** profile in your Docker MCP toolkit:

```bash
docker mcp profile export dev_workflow ./profile.yaml
```
This creates the `profile.yaml` file that defines the tools your AI assistant can use (e.g., GitHub, Jira, Confluence).

### Step 3: Set Up Your Secrets (API Keys)
To let the AI talk to your external tools, open the file named `profile.env` in this directory and fill in your keys/tokens for the MCP server you have in the exported profile.yaml:

```dotenv
# Replace the placeholder text with your actual tokens!
GITHUB_PERSONAL_ACCESS_TOKEN=your-github-token-here
JIRA_API_TOKEN=your-jira-token-here
JIRA_USERNAME=your-jira-email@example.com
JIRA_URL=https://your-company.atlassian.net
CONFLUENCE_API_TOKEN=your-confluence-token-here
CONFLUENCE_USERNAME=your-confluence-email@example.com
CONFLUENCE_URL=https://your-company.atlassian.net/wiki
```
*Tip: If you do not use Jira or Confluence, you can leave those fields blank or remove them.*

### Step 4: Run the Assistant!
Just run the provided startup script:
```bash
./run.sh
```
This script automatically pulls the latest official Docker image (`zeebote/gemini-cli-docker-mcp:latest`) and launches the assistant. It also ensures your local workspace, tools, and secrets are securely mapped to the container.

---

## 💬 How to Talk to gemini-cli

Once you run `./run.sh`, you'll see a terminal prompt where you can chat with the AI. Here are some real-world things you can ask it:

### Working with Local Files
Put some files inside your local `~/gemini/workspace` folder, then try asking:
* *"Can you list the files in my workspace?"*
* *"Read the content of index.js and tell me if there are any bugs."*
* *"Create a new markdown file in my workspace summarizing my current task list."*

### Working with GitHub
* *"Check my open pull requests in the repository my-org/my-repo."*
* *"Add a comment to issue #42 in owner/repo saying 'I am looking into this'."*

### Working with Jira and Confluence
* *"Show me the latest comments on Jira issue PROJ-123."*
* *"Search Confluence for pages about the 'auth integration' and summarize them."*

---

## 🛠️ Advanced Options (Customizing Your Setup)

You can customize where the app reads your tools, keys, and workspace folders.

By default, the `./run.sh` launcher looks for standard files in this directory. If you want to use custom paths or profile names, you can pass them as arguments when starting:

```bash
./run.sh \
  profile_file=~/my-custom-profile.yaml \
  environment_file=~/my-custom-secrets.env \
  gemini_directory=~/.my-gemini-state \
  profile_id=custom_profile
```

Alternatively, you can configure these using environment variables before launching:
```bash
DOCKER_MCP_PROFILE_FILE=~/my-custom-profile.yaml \
DOCKER_MCP_ENV_FILE=~/my-custom-secrets.env \
./run.sh
```

All parameters are optional.

### Gateway Debug Logging

Gateway diagnostics are disabled by default. Enable them for a run with:

```bash
./run.sh --debug
```

Diagnostics are appended to `.gemini/docker-mcp-gateway.log`, or to the selected `gemini_directory`. An existing log is left unchanged during runs without `--debug`. You can also enable logging with `debug=true` or `DOCKER_MCP_DEBUG=true`.


## 🔄 Managing MCP Servers

If you need to add or remove MCP servers, follow these steps:

1. **Update your MCP Profile:** Modify your `profile.yaml` or use the Docker MCP Toolkit to update your profile definitions, then re-export the profile:
   ```bash
   docker mcp profile export <your_profile_id> ./profile.yaml
   ```

2. **Update Secrets (if necessary):** If you added new MCP servers, ensure that `profile.env` contains any required API keys or tokens defined by the updated `profile.yaml`.

3. **Restart the Container:** Stop the currently running container (e.g., press `Ctrl+C` in your terminal) and start it again to apply the changes:
   ```bash
   ./run.sh
   ```

---

## 🔒 Security Built-In

Since this container connects to your host Docker engine to manage helper tools, security is a top priority:
* **Host Protection:** The AI assistant runs in a "non-root" container environment. It cannot gain administrator (root) access to your computer.
* **Workspace Isolation:** The AI can only view or change files inside the designated `~/gemini/workspace` folder. The rest of your hard drive is completely hidden and inaccessible.
* **Ephemeral Secrets:** Your API keys are read in-memory and converted to secure temporary files that vanish as soon as the container is stopped. They are never burned into the Docker image or stored permanently in Docker's databases.
* **Signature Verification:** The Gateway strictly verifies the digital signatures of the tools it runs to make sure no unauthorized or tampered tools are executed.
