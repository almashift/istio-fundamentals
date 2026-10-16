# MeshMart: one image for every service in the store (web, catalog, cart, orders, loadgen).
# Python standard library only, so there is nothing to pip install. curl is included so
# students can `kubectl exec ... -- curl` from any MeshMart pod.
FROM python:3.12-alpine
RUN apk add --no-cache curl && adduser -D -u 10001 meshmart
COPY app.py /app/app.py
USER 10001
EXPOSE 8080
ENTRYPOINT ["python", "-u", "/app/app.py"]
