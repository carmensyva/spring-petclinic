pipeline {
    agent {
        label 'skopeo'
    }

    environment {
        APP_NAME = "petclinic"
        PROJECT_NAME = "spring"
        REPO_URL = "github.com/carmensyva/spring-petclinic.git"
        BRANCH_NAME = "main"
        LANGUAGE = "java"
        DEPLOYMENT_YAML_PATH = "values/deployment-app.yaml"
        INT_REGISTRY_DEV = "image-registry.openshift-image-registry.svc:5000"
        EXT_REGISTRY_HARBOR = "harbor.dev.mibocp.co.id"
        OCP = "https://api.dev.mibocp.co.id:6443"
        HOSTED_REPO_URL = "http://nexus-service.nexus.svc.cluster.local:8081/repository/mib-maven-hosted/"
        TRIVY_REPORT_PATH = "trivy-scan-report.html"
        GIT_TAG = ""
        OC_TOKEN = ""
    }

    stages {
        stage('Initialize') {
            steps {
                script {
                    GIT_TAG = sh(returnStdout: true, script: "git rev-parse --short=8 HEAD").trim()
                    OC_TOKEN = sh(script: 'oc whoami -t', returnStdout: true).trim()
                }
            }
        }

        stage('Git Clone') {
            steps {
                script {
                    sh "git config --global http.sslVerify false"
                }
                withCredentials([usernamePassword(credentialsId: 'cred', usernameVariable: 'USERNAME', passwordVariable: 'PASSWORD')]) {
                    sh "git clone https://${USERNAME}:${PASSWORD}@${REPO_URL} source"
                }
            }
        }

        stage('Clone Trivy Repository') {
            steps {
                sh "git clone https://github.com/aquasecurity/trivy.git trivy-source"
            }
        }

        stage('SonarQube Analysis') {
            steps {
                dir("source") {
                    sh "git fetch"
                    sh "git switch ${BRANCH_NAME}"
                    withCredentials([string(credentialsId: 'sonar-token', variable: 'SONAR_TOKEN')]) {
                        sh "mvn clean verify sonar:sonar -s settings-sonar.xml -Dsonar.login=${SONAR_TOKEN} -Dcheckstyle.skip"
                    }
                }
            }
        }

        stage('App Build') {
            steps {
                dir("source") {
                    sh "git fetch"
                    sh "git switch ${BRANCH_NAME}"
                    withCredentials([usernamePassword(credentialsId: 'nexusid', usernameVariable: 'NEXUS_USERNAME', passwordVariable: 'NEXUS_PASSWORD')]) {
                        sh "mvn clean deploy -Dmaven.test.skip=true -s settings-nexus.xml -DaltDeploymentRepository=nexus::default::${HOSTED_REPO_URL} -Dmaven.wagon.http.ssl.insecure=true -Dmaven.wagon.http.ssl.allowall=true -Dmaven.wagon.http.ssl.ignore.validity.dates=true"
                    }
                }
            }
        }

        stage('App Push') {
            steps {
                dir("source") {
                    script {
                        sh "mkdir -p build-folder/target/ build-folder/apps/"
                        sh "cp dockerfile build-folder/Dockerfile"
                        sh "cp target/*.jar build-folder/target/"

                        sh "cat build-folder/Dockerfile | oc new-build -D - --name ${APP_NAME} || true"
                        sh "oc start-build ${APP_NAME} --from-dir=build-folder/. --follow --wait"
                        sh "oc tag cicd/${APP_NAME}:latest ${PROJECT_NAME}/${APP_NAME}:${GIT_TAG}"
                    }
                }
            }
        }

        stage('Trivy Image Scan') {
            steps {
                dir("source") {
                    script {
                        env.XDG_RUNTIME_DIR = '/tmp/run'
                        sh "mkdir -p /tmp/run"
                        sh "oc registry login --skip-check"
                        def templatePath = "${env.WORKSPACE}/trivy-source/contrib/html.tpl"
                        sh "trivy image --format template --template '@${templatePath}' --output ${TRIVY_REPORT_PATH} --insecure default-route-openshift-image-registry.apps.dev.mibocp.co.id/${PROJECT_NAME}/${APP_NAME}:${GIT_TAG}"
                    }
                }
            }
        }

        stage('Publish Trivy Report') {
            steps {
                dir("source") {
                    publishHTML(target: [
                        reportName: 'Trivy Scan',
                        reportDir: '.',
                        reportFiles: "${TRIVY_REPORT_PATH}",
                        keepAll: true,
                        allowMissing: false,
                        alwaysLinkToLastBuild: true
                    ])
                }
            }
        }

        stage('Push Image to Harbor') {
            steps {
                dir("source") {
                    script {
                        env.XDG_RUNTIME_DIR = '/tmp/run'
                        sh "mkdir -p /tmp/run"
                        sh "oc registry login --skip-check"

                        withCredentials([usernamePassword(credentialsId: 'harborid', usernameVariable: 'USERNAME', passwordVariable: 'PASSWORD')]) {
                            sh "skopeo copy --remove-signatures --src-creds=jenkins:${OC_TOKEN} --src-tls-verify=false docker://${INT_REGISTRY_DEV}/${PROJECT_NAME}/${APP_NAME}:${GIT_TAG} docker://${EXT_REGISTRY_HARBOR}/${LANGUAGE}/${PROJECT_NAME}_${APP_NAME}:${GIT_TAG} --dest-creds ${USERNAME}:${PASSWORD} --dest-tls-verify=false"
                            sh "oc tag cicd/${APP_NAME}:latest ${PROJECT_NAME}/${APP_NAME}:latest"
                            sh "skopeo copy --remove-signatures --src-creds=jenkins:${OC_TOKEN} --src-tls-verify=false docker://${INT_REGISTRY_DEV}/${PROJECT_NAME}/${APP_NAME}:latest docker://${EXT_REGISTRY_HARBOR}/${LANGUAGE}/${PROJECT_NAME}_${APP_NAME}:latest --dest-creds ${USERNAME}:${PASSWORD} --dest-tls-verify=false"
                        }
                    }
                }
            }
        }

        stage('Update Deployment YAML') {
            steps {
                dir("source") {
                    sh "sed -i 's|image:.*|image: ${EXT_REGISTRY_HARBOR}/${LANGUAGE}/${PROJECT_NAME}_${APP_NAME}:${GIT_TAG}|g' ${DEPLOYMENT_YAML_PATH}"
                }
            }
        }

        stage('Commit and Push Changes') {
            steps {
                dir("source") {
                    withCredentials([string(credentialsId: 'github-token', variable: 'GITHUB_TOKEN')]) {
                        sh "git config user.email 'gading.iantrisna1@gmail.com'"
                        sh "git config user.name 'carmensyva'"
                        sh "git add ${DEPLOYMENT_YAML_PATH}"
                        sh "git commit -m 'Update deployment YAML with new image tag ${GIT_TAG}'"
                        sh "git push https://${GITHUB_TOKEN}@${REPO_URL} ${BRANCH_NAME}"
                    }
                }
            }
        }
    }
}
