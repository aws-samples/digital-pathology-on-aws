ARG PARENT_IMAGE=openmicroscopy/omero-server:latest
FROM ${PARENT_IMAGE}

USER root

Add Figure_To_Pdf.py /opt/omero/server/OMERO.server/lib/scripts/omero/figure_scripts 

RUN /opt/omero/server/venv3/bin/pip install \
        omero-cli-duplicate \
        omero-metadata \
        omero-cli-render \
        reportlab \
        markdown

USER omero-server
