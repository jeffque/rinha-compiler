from node:20.6
COPY ast2bcb.js ast2bcb.js
COPY rinha-bcb/bcb.sh rinha-bcb/bcb.sh
ENV AST_SOURCE /var/rinha/source.rinha.json
CMD node ast2bcb.js
