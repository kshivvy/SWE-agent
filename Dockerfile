FROM python:3.11

# Set the working directory
WORKDIR /app

# Install nodejs
RUN apt update && \
    apt install -y nodejs npm && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Install Docker CLI using the official Docker installation script
RUN curl -fsSL https://get.docker.com -o get-docker.sh && \
    sh get-docker.sh

# Install the Google Cloud SDK. This is required to run gcloud commands.
RUN curl -sSL https://sdk.cloud.google.com | bash
ENV PATH $PATH:/root/google-cloud-sdk/bin

# Install a local, development version of LiteLLM.
RUN git clone https://github.com/kshivvy/litellm.git && cd litellm && git checkout 57e929d
RUN pip install -e ./litellm

# Copy the application code
# Do this last to take advantage of the docker layer mechanism
COPY . /app

# Install all other Python dependencies.
RUN pip install -e '.'

# Install react dependencies ahead of time
RUN cd sweagent/frontend && npm install

# Copy the entrypoint script and make it executable
COPY entrypoint.sh /app/entrypoint.sh
RUN chmod +x /app/entrypoint.sh

ENTRYPOINT ["/app/entrypoint.sh"]