Spine-Leaf Datacenter Fabric Lab (Mini - 9 thiết bị)

Lab mô phỏng kiến trúc mạng Spine-Leaf của datacenter hiện đại, chạy hoàn toàn trên máy cá nhân bằng Containerlab + Arista cEOS, tự động hoá cấu hình bằng Ansible theo hướng NetDevOps.

Đây là bản mini (9 thiết bị) — bước đệm để kiểm chứng tính ổn định và chuẩn hoá quy trình trước khi scale lên bản đầy đủ 20 thiết bị.

Kiến trúc
                [ spine1 ]     [ spine2 ]
                 /   |   \      /   |   \
                /    |    \    /    |    \
          [leaf1] [leaf2] [leaf3] [leaf4 - Border Leaf]
             |       |       |          |
          (fabric) (fabric)  |       [edge - NAT] --- Internet
                              |
                    [web01]  [db01]
                   (Apache)  (MySQL)
2 Spine: spine1, spine2 — full-mesh BGP với tất cả Leaf
4 Leaf: leaf1-leaf3 thường, leaf4 đóng vai trò Border Leaf (nối ra edge)
1 Edge: NAT ra Internet
2 Endpoint: web01 (Apache), db01 (MySQL) — mô phỏng traffic ứng dụng thật xuyên qua fabric
Công nghệ
Thành phần	Công cụ
Giả lập mạng	Containerlab
Hệ điều hành switch	Arista cEOS 4.36.1F (kind arista_ceos)
Tự động hoá	Ansible (arista.eos collection, network_cli)
Môi trường chạy	WSL2 (Ubuntu) + Docker
Công thức địa chỉ (IP addressing scheme)

Scheme này được thiết kế để scale thẳng lên bản 20 thiết bị chỉ bằng cách đổi inventory/host_vars, không phải sửa logic:

Loopback Spine: 10.255.0.<spine_id>/32
Loopback Leaf: 10.255.1.<leaf_id>/32
Link Spine-Leaf: 10.<spine_id>.<leaf_id>.0/31
ASN: Spine dùng chung 65000, Leaf = 65000 + leaf_id
Subnet Endpoint: 172.16.<leaf_id>.0/24
Cấu trúc thư mục
.
├── spine-leaf-fabric-mini.clab.yml   # Topology file chinh (containerlab)
├── ansible/
│   ├── preflight.yml                 # Entry-point duy nhat - chay dau tien moi phien lam viec
│   ├── deploy_config.yml             # Day cau hinh BGP qua template Jinja2
│   ├── test_connectivity.yml
│   ├── inventory.ini
│   ├── group_vars/ , host_vars/      # Bien theo group / theo tung thiet bi
│   └── templates/                    # Jinja2 template cho spine / leaf
└── configs-backup/
    ├── *.cfg                         # Startup-config cua 6 switch (auto load lai khi deploy)
    └── setup-linux-nodes.sh          # Khoi phuc IP/Apache/MySQL cho web01, db01

Ghi chú: clab-spine-leaf-mini/ là thư mục runtime do Containerlab tự sinh ra mỗi lần deploy (log, cert, state...). Thư mục này không được commit vào git (xem .gitignore) vì nó không phải source code, chỉ là trạng thái chạy — tái tạo lại hoàn toàn mỗi lần redeploy.

Cách chạy

Yêu cầu: WSL2 + Docker + Containerlab + Ansible (ansible-galaxy collection install arista.eos).

bash
git clone <repo-url>
cd spine-leaf-mini/ansible
ansible-playbook preflight.yml -K

preflight.yml là entry-point duy nhất, chạy đầu mỗi phiên làm việc (đặc biệt sau khi tắt máy/restart WSL2). Nó tự động, idempotent (an toàn chạy lại nhiều lần) và xử lý gộp các bước:

Kiểm tra số container đang chạy, deploy lại toàn bộ lab nếu cần (containerlab deploy --reconfigure)
Hiển thị bảng trạng thái (containerlab inspect)
Khôi phục IP/Apache/MySQL cho web01, db01 nếu bị mất (do bị tạo lại từ image gốc mỗi lần redeploy)
Chờ SSH sẵn sàng trên các switch, kiểm tra BGP đã Established đủ số peer kỳ vọng
Đảm bảo MySQL trên db01 đúng cấu hình (bind-address, database, quyền appuser), test query xuyên fabric từ web01

Chạy kiểm tra khô (không thay đổi gì) bằng:

bash
ansible-playbook preflight.yml -K --check --diff
Lưu ý đã biết (sẽ xử lý ở bước hardening tiếp theo)
Password MySQL (appuser) hiện đang ở dạng plaintext trong preflight.yml — sẽ chuyển sang Ansible Vault.
Việc backup startup-config switch (configs-backup/*.cfg) hiện vẫn là bước tay — sẽ tự động hoá vào trong preflight.yml.
Playbook hiện là flat, chưa tách theo Ansible Roles — sẽ restructure trước khi scale lên bản 20 thiết bị.
Lộ trình
 Phase 1: Cấu hình tay, kiểm chứng BGP full-mesh + traffic HTTP/MySQL xuyên fabric
 Phase 2: Tự động hoá bằng Ansible (SSH-key auth, idempotency, preflight.yml)
 Hardening: Ansible Vault, backup config tự động, restructure thành Roles
 Scale lên bản đầy đủ 20 thiết bị (4 Spine / 10 Leaf / 5 Endpoint / 1 Edge)
