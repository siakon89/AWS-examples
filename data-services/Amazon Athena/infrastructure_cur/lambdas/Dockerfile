 FROM public.ecr.aws/lambda/python:3.12

# Copy requirements.txt
COPY requirements.txt ${LAMBDA_TASK_ROOT}

# Install the dependencies
RUN pip install -r requirements.txt

# Copy function code
COPY untagged_resources_reporter.py ${LAMBDA_TASK_ROOT}

# Set the CMD to your handler
CMD [ "untagged_resources_reporter.lambda_handler" ]