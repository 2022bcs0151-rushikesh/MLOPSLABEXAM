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
                script {
                    if (isUnix()) {
                        sh 'docker build -t $IMAGE_NAME .'
                    } else {
                        powershell 'docker build -t $env:IMAGE_NAME .'
                    }
                }
            }
        }

        stage('Run Container') {
            steps {
                script {
                    if (isUnix()) {
                        sh 'docker run -d --name $CONTAINER_NAME -p $PORT:8000 $IMAGE_NAME'
                    } else {
                        powershell 'docker run -d --name $env:CONTAINER_NAME -p "$env:PORT:8000" $env:IMAGE_NAME'
                    }
                }
            }
        }

        stage('Wait For Readiness') {
            steps {
                script {
                    if (isUnix()) {
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
                    } else {
                        powershell '''
                            $ErrorActionPreference = 'Stop'

                            $deadline = (Get-Date).AddSeconds(30)
                            $url = "http://127.0.0.1:$env:PORT/health"

                            while ((Get-Date) -lt $deadline) {
                                $code = 0
                                try {
                                    $resp = Invoke-WebRequest -Uri $url -Method Get -TimeoutSec 3
                                    $code = [int]$resp.StatusCode
                                } catch {
                                    if ($_.Exception.Response -and $_.Exception.Response.StatusCode) {
                                        $code = [int]$_.Exception.Response.StatusCode
                                    }
                                }

                                if ($code -eq 200) {
                                    Write-Host "Service is ready (HTTP 200)"
                                    exit 0
                                }

                                Write-Host "Not ready yet (HTTP $code). Retrying in 5s..."
                                Start-Sleep -Seconds 5
                            }

                            Write-Host "Timed out waiting for readiness"
                            exit 1
                        '''
                    }
                }
            }
        }

        stage('Valid Predict Request') {
            steps {
                script {
                    if (isUnix()) {
                        sh '''
                            set -eu
                            resp=$(curl -s -X POST http://127.0.0.1:${PORT}/predict \
                              -H "Content-Type: application/json" \
                              -d '{"alcohol":10}')
                            echo "Response: $resp"
                            echo "$resp" | grep -q 'wine_quality'
                            echo "Name: ${STUDENT_NAME} | Roll: ${ROLL_NUMBER} | Output: $resp"
                        '''
                    } else {
                        powershell '''
                            $ErrorActionPreference = 'Stop'

                            $url = "http://127.0.0.1:$env:PORT/predict"
                            $resp = Invoke-RestMethod -Uri $url -Method Post -ContentType 'application/json' -Body '{"alcohol":10}'

                            if (-not ($resp.PSObject.Properties.Name -contains 'wine_quality')) {
                                throw 'Response missing wine_quality'
                            }

                            $json = $resp | ConvertTo-Json -Compress
                            Write-Host "Name: $env:STUDENT_NAME | Roll: $env:ROLL_NUMBER | Output: $json"
                        '''
                    }
                }
            }
        }

        stage('Invalid Predict Request') {
            steps {
                script {
                    if (isUnix()) {
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
                    } else {
                        powershell '''
                            $ErrorActionPreference = 'Stop'

                            $url = "http://127.0.0.1:$env:PORT/predict"
                            $code = 0
                            try {
                                $resp = Invoke-WebRequest -Uri $url -Method Post -ContentType 'application/json' -Body '{"alcohol":"bad"}' -TimeoutSec 5
                                $code = [int]$resp.StatusCode
                            } catch {
                                if ($_.Exception.Response -and $_.Exception.Response.StatusCode) {
                                    $code = [int]$_.Exception.Response.StatusCode
                                }
                            }

                            Write-Host "Invalid request HTTP status: $code"
                            if ($code -lt 400) {
                                throw "Expected 4xx/5xx for invalid input, got $code"
                            }
                        '''
                    }
                }
            }
        }

        stage('Stop And Remove Container') {
            steps {
                script {
                    if (isUnix()) {
                        sh 'docker rm -f $CONTAINER_NAME || true'
                    } else {
                        powershell 'try { docker rm -f $env:CONTAINER_NAME | Out-Null } catch { }'
                    }
                }
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
            script {
                if (isUnix()) {
                    sh 'docker rm -f $CONTAINER_NAME || true'
                } else {
                    powershell 'try { docker rm -f $env:CONTAINER_NAME | Out-Null } catch { }'
                }
            }
        }
    }
}
