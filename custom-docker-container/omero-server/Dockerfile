ARG PARENT_IMAGE=openmicroscopy/omero-server:latest
FROM ${PARENT_IMAGE}

USER root

RUN /opt/omero/server/venv3/bin/pip install \
        omero-cli-duplicate \
        omero-metadata \
        omero-cli-render 

USER omero-web
