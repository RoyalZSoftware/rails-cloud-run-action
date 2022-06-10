# Rails Cloud Run Action

```
steps:
  deploy_production:
    needs: [build]
    name: Deploy to Production
    if: ${{ github.event_name == 'release' }}
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - id: create_environment
        uses: royalzsoftware/rails-cloud-run-action@main
        with:
          project_id: ${{env.PROJECT_ID}} # gcp project id
          project_name: ${{env.PROJECT_NAME}} # prefix for all projects
          google_application_credentials: ${{secrets.GOOGLE_CREDENTIALS}} # content of json file, not path
          rails_master_key: ${{secrets.RAILS_MASTER_KEY}} # content of config/master.key
          environment_name: production
          environment_tag: ${GITHUB_REF##*/} # tag names
          requires_load_balancer: true # if true: creates dns records and load balancers
          domain: ${{env.DOMAIN}} # domain - royalzsoftware.de
          rails_env: production # or staging or development
    environment:
      name: Production
      url: https://production.app.${{env.DOMAIN}}
```
