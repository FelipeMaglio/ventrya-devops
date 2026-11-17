# Imagem da Ventrya API (Java 21 + Spring Boot)
# O .jar é gerado e publicado pela pipeline de CI; a Release monta esta imagem
# com o artefato e envia ao ACR.
FROM eclipse-temurin:21-jre

RUN useradd --system --uid 1001 appuser
WORKDIR /app
COPY app.jar app.jar
RUN chown appuser /app/app.jar
USER appuser

EXPOSE 8080
ENTRYPOINT ["java", "-XX:MaxRAMPercentage=75", "-jar", "/app/app.jar"]
