######################################################################
# Official Superset image
######################################################################
FROM apache/superset:1.2.0 AS superset-official

# REPLACING FILES IN OFFICIAL IMAGE
COPY superset/superset-frontend /app/superset-frontend
COPY superset/superset /app/superset

######################################################################
# Node stage to deal with static asset construction
######################################################################
FROM node:14 AS superset-node

ARG NPM_VER=7
RUN npm install -g npm@${NPM_VER}

ARG NPM_BUILD_CMD="build"
ENV BUILD_CMD=${NPM_BUILD_CMD}

# NPM ci first, as to NOT invalidate previous steps except for when package.json changes
RUN mkdir -p /app/superset-frontend
RUN mkdir -p /app/superset/assets

COPY ./superset/docker/frontend-mem-nag.sh /

COPY --from=superset-official /app/superset-frontend/package* /app/superset-frontend/

RUN /frontend-mem-nag.sh \
        && cd /app/superset-frontend \
        && npm ci

# Next, copy in the rest and let webpack do its thing
COPY --from=superset-official /app/superset-frontend /app/superset-frontend

# This is BY FAR the most expensive step (thanks Terser!)
RUN cd /app/superset-frontend \
        && npm run ${BUILD_CMD} \
        && rm -rf node_modules

######################################################################
# Final image
######################################################################
FROM superset-official AS superset-tsp

COPY --from=superset-node /app/superset/static/assets /app/superset/static/assets