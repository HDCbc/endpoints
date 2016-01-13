WebARchive built using the following in a Dockerfile:

WORKDIR /app/
RUN apt-get update; \
    apt-get install -y maven
COPY . .
RUN sed -i 's/validateXml="false"//' ./jspc.xml; \
    sed -i '/DbConnectionFilter.releaseAllThreadDbResources();/a \\t\t\tSystem.exit(0);' \
      src/main/java/org/oscarehr/common/service/E2ESchedulerJob.java
RUN mvn -Dmaven.test.skip=true package; \
    cp ./target/oscar-SNAPSHOT.war ${CATALINA_BASE}/webapps/oscar12.war; \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /root/.m2/ /app/local_repo/ /app/
