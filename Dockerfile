# Use a specific, immutable base image tag to make sure this layer is cached.
# Using 'slim' makes the image much smaller.
FROM python:3.11.9-slim-bookworm

# Set the working directory
WORKDIR /app

# Combine RUN commands to reduce layers and leverage caching.
RUN apt-get update && \
    # Install additional commands, because they are not included in the slim
    # image.
    apt-get install -y --no-install-recommends \
    nodejs \
    git \
    curl \
    && \
    # Clean up apt cache to reduce image size.
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Create a symlink for python3, so gcloud can find it.
RUN ln -s /usr/local/bin/python3 /usr/bin/python3

# Install Docker CLI using the official Docker installation script
RUN curl -fsSL https://get.docker.com -o get-docker.sh && \
    sh get-docker.sh

# Install the Google Cloud SDK. This is required to run gcloud commands.
RUN curl -sSL https://sdk.cloud.google.com | bash
ENV PATH $PATH:/root/google-cloud-sdk/bin

# Install a local, development version of LiteLLM.
RUN git clone https://github.com/kshivvy/litellm.git && cd litellm && git checkout b9ed97c
RUN pip install -e ./litellm

# Copy only the files needed for Python dependency installation.
COPY pyproject.toml README.md ./

# Copy the package source code so 'pip' can find the version.
COPY sweagent ./sweagent

# Install all other Python dependencies.
RUN pip install --no-cache-dir -e '.'

# Copy the rest of the application code.
# Do this last to take advantage of the docker layering mechanism.
COPY . /app

# Create a trajectory directory. trajectories/ is included in the .gitignore
# file, which is used as a default .gcloudignore file. Without an explicit
# trajectories directory created, the Cloud Batch job will crash.
RUN mkdir -p /app/trajectories

# Make the entrypoint script executable.
RUN chmod +x /app/entrypoint.sh

ENTRYPOINT ["/app/entrypoint.sh"]