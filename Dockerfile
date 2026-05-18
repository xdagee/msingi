FROM alpine:latest
RUN apk add --no-cache ca-certificates

WORKDIR /app

# Copy the pre-built Linux AMD64 binary
COPY build/msingi-linux-amd64 /usr/local/bin/msingi
RUN chmod +x /usr/local/bin/msingi

# Copy runtime config files
COPY agents.json skills.json /app/

# Msingi binary relies on the working directory having these config files
# unless overridden by environment variables or it uses embed for templates.
# The binary expects agents.json and skills.json in CWD.

ENTRYPOINT ["msingi"]
