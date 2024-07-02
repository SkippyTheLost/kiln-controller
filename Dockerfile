# Start with the base image
ARG PYTHON_VERSION=3.12.4
FROM python:${PYTHON_VERSION}-alpine as builder

# Prevents Python from writing pyc files.
ENV PYTHONDONTWRITEBYTECODE=1

# Keeps Python from buffering stdout and stderr to avoid situations where
# the application crashes without emitting any logs due to buffering.
ENV PYTHONUNBUFFERED=1

WORKDIR /app

# Install build dependencies
RUN apk add --no-cache --virtual .build-deps \
    gcc musl-dev python3-dev libffi-dev build-base

# Install the dependencies
COPY requirements.txt .
RUN pip install --upgrade pip setuptools \
    && pip install --no-cache-dir -r requirements.txt

# Copy the source code into the container
COPY ./lib ./lib
COPY ./public ./public
COPY ./storage ./storage
COPY ./*.py ./

# Create the final image
FROM python:${PYTHON_VERSION}-alpine

# Prevents Python from writing pyc files.
ENV PYTHONDONTWRITEBYTECODE=1

# Keeps Python from buffering stdout and stderr to avoid situations where
# the application crashes without emitting any logs due to buffering.
ENV PYTHONUNBUFFERED=1

WORKDIR /app

# Install runtime dependencies
RUN apk add --no-cache libffi

# Copy the application from the builder image
COPY --from=builder /usr/local/lib/python3.12/site-packages /usr/local/lib/python3.12/site-packages
COPY --from=builder /usr/local/bin /usr/local/bin
COPY --from=builder /app /app

# Create a non-privileged user that the app will run under
ARG UID=10001
RUN adduser \
    --disabled-password \
    --gecos "" \
    --home "/nonexistent" \
    --shell "/sbin/nologin" \
    --no-create-home \
    --uid "${UID}" \
    kiln-controller

# Set the non-privileged user as the owner of the files
RUN chown -R kiln-controller /app \
    && mkdir -p /app/storage \
    && chmod -R 777 /app/storage

# Use the non-privileged user
USER kiln-controller

# Declare a volume
VOLUME /app/storage

# Expose the port that the application listens on
EXPOSE 80

# Run the application
CMD ["python", "./kiln-controller.py"]
