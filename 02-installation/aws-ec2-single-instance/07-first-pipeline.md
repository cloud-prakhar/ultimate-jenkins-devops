# 07 - First Pipeline

Use the example in [examples/first-pipeline/Jenkinsfile](./examples/first-pipeline/Jenkinsfile).

## Minimal Declarative Pipeline

```groovy
pipeline {
    agent any
    stages {
        stage('Hello') {
            steps {
                sh 'echo Jenkins pipeline on EC2 is working'
            }
        }
    }
}
```

## Break-It Exercise

- change the agent label to a non-existent label
- observe the build queue and error message
- fix the label and rebuild
