pipeline {
    agent any

    environment {
        IMAGE_NAME = 'wine-quality-api:ci'
        PORT = '8000'
        CONTAINER_NAME = "wine-quality-api-${env.BUILD_TAG}".replaceAll('[^a-zA-Z0-9_.-]', '-')

        STUDENT_NAME = 'rushikesh'
        ROLL_NUMBER = '2022bcs0151'
    }

    stages {
        stage('Build Image') {
            steps {
                sh 'docker build -t $IMAGE_NAME .'
            }
        }

        stage('Run Container') {
            steps {
                sh 'docker run -d --name $CONTAINER_NAME -p $PORT:8000 $IMAGE_NAME'
            }
        }

        stage('Wait For Readiness') {
            steps {
                script {
                    sh '''
                        set -eu
                        deadline=$((SECONDS+30))
                        until [ $SECONDS -ge $deadline ]; do
                          code=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:${PORT}/health || true)
                          if [ "$code" = "200" ]; then
                            echo "Service is ready (HTTP 200)"
                            exit 0
                          fi
                          echo "Not ready yet (HTTP $code). Retrying in 5s..."
                          sleep 5
                        done
                        echo "Timed out waiting for readiness"
                        exit 1
                    '''
                }
            }
        }

        stage('Valid Predict Request') {
            steps {
                script {
                    sh '''
                        set -eu
                        resp=$(curl -s -X POST http://127.0.0.1:${PORT}/predict \
                          -H "Content-Type: application/json" \
                          -d '{"alcohol":10}')
                        echo "Response: $resp"
                        echo "$resp" | grep -q 'wine_quality'
                        echo "Name: ${STUDENT_NAME} | Roll: ${ROLL_NUMBER} | Output: $resp"
                    '''
                }
            }
        }

        stage('Invalid Predict Request') {
            steps {
                script {
                    sh '''
                        set -eu
                        code=$(curl -s -o /dev/null -w "%{http_code}" -X POST http://127.0.0.1:${PORT}/predict \
                          -H "Content-Type: application/json" \
                          -d '{"alcohol":"bad"}' || true)
                        echo "Invalid request HTTP status: $code"
                        if [ "$code" -lt 400 ]; then
                          echo "Expected 4xx/5xx for invalid input"
                          exit 1
                        fi
                    '''
                }
            }
        }

        stage('Stop And Remove Container') {
            steps {
                sh 'docker rm -f $CONTAINER_NAME || true'
            }
        }
    }

    post {
        success {
            echo 'SUCCESS'
        }
        failure {
            echo 'FAILURE'
        }
        always {
            sh 'docker rm -f $CONTAINER_NAME || true'
        }
    }
}
