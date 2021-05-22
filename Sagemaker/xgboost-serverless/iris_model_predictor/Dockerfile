FROM public.ecr.aws/lambda/python:3.7

COPY requirements.txt ./

RUN python3.7 -m pip install -r requirements.txt -t .

COPY app.py authorizer.py ./

COPY model/iris_model.pkl ./

# Command can be overwritten by providing a different command in the template directly.
CMD ["app.lambda_handler"]
