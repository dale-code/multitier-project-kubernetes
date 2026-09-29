# Capstone Project — Multi-Tier Web Application on GCP

**Deploy a five-tier web application, containerized locally and provisioned to Google Cloud with Infrastructure as Code.**

> This is a specification, not a walkthrough. It tells you *what* success looks like and *what constraints* to work within. The *how* is your job,that's the point. Where you see, it's a hint, not a step. Where you see, it's a trap people fall into.

---

## 1. The scenario

You've been handed a Java web application that stores data in PostgreSQL, caches reads in Memcached, and pushes background jobs to RabbitMQ. Users reach it through an Nginx reverse proxy. Your job is to make it run — first on your own machine in a reproducible VM, then containerized, then deployed to GCP entirely through code.

You will deliver **three environments of increasing rigor**:

1. **Local VM** (Vagrant) — prove the stack runs on one provisioned box.
2. **Containerized** (Docker Compose) — each service in its own container, orchestrated together.
3. **Cloud** (Terraform + GCP) — the whole thing provisioned to Google Cloud with no manual clicking.

Each phase builds on the last. Don't skip ahead.

---

## 2. The mandated stack

These are **fixed**. Part of the challenge is making *these specific pieces* talk to each other — don't substitute.

| Tier | Technology | Role |
|---|---|---|
| Reverse proxy | **Nginx** | Public entry point; forwards to the app |
| App server | **Apache Tomcat** | Runs the Java web app (a `.war`) |
| Application | **Java / Spring** (Spring Boot or Spring MVC WAR) | The business logic |
| Database | **PostgreSQL** | Persistent storage |
| Cache | **Memcached** | Caches expensive reads |
| Message broker | **RabbitMQ** | Background/async messaging |
| Build tool | **Maven** | Produces the `.war` artifact |

---

## 3. Phase 1 — Local VM with Vagrant

**Goal:** one `vagrant up` brings up a Linux VM where the full stack runs and serves a page.

### Specifications

- A single `Vagrantfile` provisions the VM. `vagrant up` from a clean checkout must work with no manual steps afterward.
- All five services run and are wired together: hitting the proxy returns a page that demonstrably touches the DB, the cache, and the queue.
- The VM forwards a port so you can load the app from your host browser.
- Provisioning is scripted (shell provisioner or similar) and **idempotent** — running it twice doesn't break anything.

### What you must figure out yourself

- How the services find each other (ports, hostnames, service start order).
- Where the Tomcat `.war` gets deployed and how Nginx proxies to it.
- How to inject DB credentials and connection strings without hard-coding secrets in the app.

Service **start order** matters: the app will crash-loop if it boots before PostgreSQL is accepting connections. Think about health/readiness, not just "start everything."

"Works after I SSH in and run three commands" does **not** meet the spec. If it isn't in the provisioner, it doesn't count.

### Phase 1 is done when

`vagrant destroy -f && vagrant up` on a clean machine produces a working app with zero manual intervention.

---

## 4. Phase 2 — Containerize with Docker Compose

**Goal:** replace the monolithic VM with one container per service, orchestrated by a single Compose file.

### Specifications

- A `docker-compose.yml` defines **all five services** (Nginx, Tomcat/app, PostgreSQL, Memcached, RabbitMQ).
- `docker compose up` brings the entire stack online and the app is reachable on a published port.
- Each service is its own container. **No two services share a container.**
- Data that must survive a restart (the database) uses a **named volume**. Tearing down containers must not lose the database.
- Services communicate over a **Docker network** by service name, not by hardcoded IPs.
- Configuration (credentials, hostnames) comes from **environment variables** / an `.env` file, not baked into images.
- Your app image is built from a **Dockerfile** (multi-stage: build the `.war` with Maven, run it on Tomcat).

### What you must figure out yourself

- The dependency graph between services and how to express start-ordering and readiness in Compose.
- How Nginx's upstream configuration references the app container.
- How to get the built `.war` into the Tomcat image cleanly (hint: don't copy it in by hand — build it).
- How the app's config differs between "running in Vagrant" and "running in Compose," and how to avoid duplicating it.

💡 A multi-stage Dockerfile keeps your final image small: one stage runs `mvn package`, the next copies only the resulting `.war` onto a `tomcat:` base. Shipping Maven and the JDK in your runtime image is a smell.

`depends_on` controls *start order*, not *readiness*. A container can be "started" while the service inside it isn't ready for connections yet. Handle actual readiness.

Named volumes vs. bind mounts vs. anonymous volumes behave differently on teardown. Know which one keeps your data and which one silently discards it.

### Phase 2 is done when

`docker compose down && docker compose up` rebuilds and reconnects everything, the app works, and the database's data from before the restart is still there.

---

## 5. Phase 3 — Deploy to GCP with Terraform

**Goal:** provision the cloud infrastructure and run the stack on GCP **entirely through Terraform**. No console clicking to create resources.

### Specifications

- All infrastructure is defined in Terraform (`.tf` files). A reviewer can run `terraform init && terraform apply` and get a working deployment.
- The application is reachable over the public internet at an IP or URL that Terraform **outputs**.
- Networking is explicit: a VPC/subnet, and firewall rules that open **only** the ports that must be open. The database and internal services must **not** be exposed to the public internet.
- Secrets (DB password, etc.) are **not** hardcoded in `.tf` files and **not** committed to git. Use variables + a gitignored `tfvars`, or a secrets mechanism.
- `terraform destroy` cleanly removes everything with no orphaned billable resources.
- State is handled deliberately — you can explain where your state lives and why.

### Deployment approach

You must justify your choice in the README:

- **Single VM runs Compose.** Terraform provisions a Compute Engine VM; a startup script installs Docker and runs your `docker-compose.yml`. Simplest bridge from Phase 2.

Approach (a) is the shortest path to "it works on GCP" and a fine choice if your assessment priority is a working deployment. (c) teaches you the most about GCP but is the biggest scope jump.

### What you must figure out yourself

- Which ports to open to the world (think hard — the answer is *very few*) and which stay internal.
- How the app in the cloud gets its configuration and secrets at deploy time.
- How Terraform passes values (like a generated DB password or the VM's IP) between resources.
- Where Terraform state should live for something you might run more than once.

Opening `0.0.0.0/0` on the database port is an automatic fail on the security portion. Public entry is the proxy, and essentially nothing else.

A startup script that runs `docker compose up` but doesn't survive a reboot is fragile. Consider what happens when the VM restarts.

### Phase 3 is done when

From a clean state, `terraform apply` yields a URL in the outputs that serves the working app, and `terraform destroy` leaves your GCP project empty of billable resources.

---

## 6. Deliverables

A single git repository containing:

```
├── Vagrantfile                  # Phase 1
├── provision/                   # provisioning scripts
├── docker-compose.yml           # Phase 2
├── Dockerfile(s)                # app image(s)
├── .env.example                 # documents required env vars (real .env gitignored)
├── terraform/                   # Phase 3, all .tf files
│   └── terraform.tfvars.example # documents required vars (real tfvars gitignored)
├── app/                         # application source + Maven build
├── .gitignore                   # must exclude secrets, state, .env, tfvars
├── architecture.md              # diagram + explanation (see below)
└── README.md                    # how to run each phase
```

### `README.md` must include

- Exact commands to bring up each phase from scratch.
- A statement of your Phase 3 deployment choice (a/b/c) and *why*.
- Where your Terraform state lives and why.
- Anything a reviewer needs to supply (credentials, project ID).

### `architecture.md` must include

- A diagram showing all five tiers, what talks to what, and over which ports.
- Which components are public vs. internal.
- Where persistent data lives and how it survives restarts.
- Where each secret comes from at each phase.

---

## 7. Grading rubric (100 pts) — weighted toward a working deployment

| Area | Pts | What earns it |
|---|---|---|
| **Phase 3 deployment works** | **35** | `terraform apply` → reachable, functioning app on GCP. This is the headline. |
| **Phase 2 Compose works** | 20 | Full stack up with one command; data persists across restart. |
| **Phase 1 Vagrant works** | 10 | Clean `vagrant up` yields a working app, fully scripted. |
| **Infrastructure as Code quality** | 15 | Reproducible, no manual steps, sane variables/outputs, `destroy` is clean. |
| **Security & networking** | 10 | Least-privilege firewall; DB not public; secrets not committed. |
| **Architecture & documentation** | 10 | Clear diagram, honest write-up of decisions and trade-offs. |

### Automatic point loss

- Secrets committed to git (passwords, keys, `.env`, `tfvars`, `*.tfstate`) → **−15 and a talking-to**.
- Database reachable from the public internet → fails the security section.
- "It works but only after I manually..." → loses the reproducibility points for that phase.

---

## 8. Suggested timeline

| Week | Focus |
|---|---|
| 1 | Get the app building with Maven; understand each tier in isolation. |
| 2 | Phase 1 — Vagrant. Wire all five services on one VM. |
| 3 | Phase 2 — Docker Compose. One container per service. |
| 4 | Phase 3 — Terraform + GCP. Deploy, secure, document. |
| — | Buffer: cloud always takes longer than you think. |

---

## 9. Stretch goals (bonus, optional)

Only after the core works:

- **HTTPS** on the proxy with a real certificate.
- **Terraform remote state** in a GCS bucket with locking.
- **CI** that builds the `.war` and validates Terraform on every push.
- **Managed services**: swap the PostgreSQL container for Cloud SQL, Memcached for Memorystore.
- **Zero-downtime redeploy**: push a new app version without dropping the DB.
- **Autoscaling** the app tier behind a load balancer.

---

## 10. Rules of engagement

- **Search the docs, not just chat forums.** The official Nginx, Tomcat, Docker, Terraform, and GCP docs answer 90% of what you'll hit.
- **Commit often.** A working Phase 1 in git is worth more than a broken Phase 3 in your head.
- **When stuck for >30 min, change tactics** — smaller reproduction, read the logs, question an assumption. Don't grind.
- **Read the error message. Then read it again.** Most of these tools tell you exactly what's wrong; the skill is learning to listen.

> The goal isn't to follow instructions — it's to build judgment. Two students can both get full marks with different architectures. Defend yours.
