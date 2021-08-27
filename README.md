# Custom Lambda Container

Testing creating a Lambda from a custom container image

## Resources

Following along with [AWS](https://docs.aws.amazon.com/lambda/latest/dg/images-create.html#images-create-from-alt). We need a [good example](https://www.npmjs.com/package/aws-lambda-ric) for Node, though.

I'll be implementing the fake-letter Node application from this [post](https://aws.amazon.com/blogs/aws/new-for-aws-lambda-container-image-support/).

## Build & Deploy Steps

1. Create a repository if you don't already have one. Grab the repository URI, you'll use this where `${REPO_URI}` is mentioned.

   ```shell
   aws ecr create-repository --repository-name random-letter --image-scanning-configuration scanOnPush=true
   ```

1. Build and tag the image.

   ```shell
   docker build -t random-letter .
   docker tag random-letter:latest ${REPO_URI}/random-letter:latest
   ```

1. Authenticate Docker CLI with AWS ECR repository.

   ```shell
   aws ecr get-login-password | docker login --username AWS --password-stdin ${REPO_URI}
   ```

1. Push the image to ECR.

   ```shell
   docker push ${REPO_URI}/random-letter:latest
   ```

1. Follow the steps in this [blog post](https://aws.amazon.com/blogs/aws/new-for-aws-lambda-container-image-support/) starting at `Here I am using the AWS Management Console to complete the creation of the function...` to create the Lambda function from the AWS Console.

## Directory Setup

It seems like there may be two possible approaches to setting up projects, one that resembles a Serverless-framework-style collection of Lambdas and another that completely isolates each Lambda function.

However, the AWS guides in the [resources](#resources) section seem to choose a hybrid of these structures, so we'll start there.

### AWS Prescribed

```shell
.
├── .dockerignore
├── .gitignore
├── .nvmrc
├── .prettierrc
├── Dockerfile
├── README.md
└── app
    ├── app.js
    ├── package-lock.json
    └── package.json
```

It's not clear whether AWS recommends developing multiple Lambdas within the same repository using this structure. The package.json is specific to the **app** directory for a specific Lambda, but the **Dockerfile** is in the repository root. For each new Lambda, there would need to be a new **appX** directory with its own npm package but an additional corresponding **DockerfileX** in the repository root. Also in this setup, code tooling lives in the root (although this is not specifically addressed by AWS), so they would need to be able to operate correctly when the npm package is nested at a deeper level than needed configuration files.

For sharing custom Node modules across Lambdas, we could potentially have the following additional structure:

```shell
.
├── .gitignore
# ...
└── common
    ├── util1.js
    └── util2.js
```

However, this is reminiscent of a monorepo without fully adhering to a monorepo. Blurring the lines like this may be more confusing than helpful.

### Serverless Style

```shell
.
├── .dockerignore
├── .gitignore
├── .nvmrc
├── .prettierrc
├── README.md
├── common
│   ├── util1.js
│   └── util2.js
├── handler1
│   ├── Dockerfile
│   └── handler1.js
├── handler2
│   ├── Dockerfile
│   └── handler2.js
├── package-lock.json
└── package.json
```

[Serverless](https://www.serverless.com/) supports an organization that centralizes everything except for individual Lambdas. By extension, we could include the relevant **Dockerfile** with each Lambda. This allows for high reuse (similar to a monorepo) but it installs all external Node packages into each Lambda since there's only **package.json** for all Lambdas. The best solution would probably be to incorporate a bundler, like Webpack, into the build process.

### Full Isolation

```shell
.
├── README.md
├── common
│   ├── util1.js
│   ├── util2.js
│   ├── package-lock.json
│   └── package.json
├── lambda1
│   ├── .dockerignore
│   ├── .gitignore
│   ├── .nvmrc
│   ├── .prettierrc
│   ├── Dockerfile
│   ├── README.md
│   ├── handler1.js
│   ├── package-lock.json
│   └── package.json
└── lambda2
    ├── .dockerignore
    ├── .gitignore
    ├── .nvmrc
    ├── .prettierrc
    ├── Dockerfile
    ├── README.md
    ├── handler2.js
    ├── package-lock.json
    └── package.json
```

This would be a more advanced monorepo, which would most likely requires more advanced tooling. It's possible that select tooling (e.g. Prettier) could be moved to the repository root, but it would have to be on a case-by-case basis. In this case, it would be recommended to open only single a Lambda per IDE window to enable proper tooling.

## Dependencies

The Lambda Runtime Interface Client needs CMake 3.9 or newer, which is standard on Debian Buster or newer and needs autoreconf which is not installed on the `-slim` Node base images. The `-slim` image can then be used on the final image where the Node Lambda will actually execute.
