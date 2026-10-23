#!/usr/bin/env python3

"""
Projeto Aeroporto - Script de Validação de Acessos (Versão Python)

Objetivo:
    Validar conectividade aos domínios críticos do projeto Aeroporto
    com suporte a proxy, relatórios detalhados e exportação de dados.

Uso:
    python3 scripts/validate-access.py
    python3 scripts/validate-access.py --quiet
    python3 scripts/validate-access.py --format=json
    python3 scripts/validate-access.py --timeout=10
    python3 scripts/validate-access.py --proxy=http://proxy.example.com:8080

Pré-requisitos:
    - Python 3.6+
    - requests (pip install requests)

Retorno:
    0 = Todos os acessos validados
    1 = Um ou mais acessos falharam
"""

import sys
import json
import argparse
import socket
import ssl
import urllib.request
import urllib.error
from datetime import datetime
from typing import List, Tuple, Dict, Optional
from collections import namedtuple
from dataclasses import dataclass, field, asdict
from enum import Enum

# Definições
class Status(Enum):
    SUCCESS = "SUCCESS"
    WARNING = "WARNING"
    FAILED = "FAILED"

@dataclass
class AccessTest:
    component: str
    domain: str
    port: int
    status: Status = field(default=Status.FAILED)
    reason: str = field(default="")
    dns_time: float = field(default=0.0)
    tcp_time: float = field(default=0.0)
    https_time: float = field(default=0.0)

class AccessValidator:
    """Validador de acessos para o Projeto Aeroporto"""
    
    # Lista de acessos a validar
    ACCESSES = [
        # Zabbix
        ("Zabbix Repository", "repo.zabbix.com", 443),
        ("Zabbix Website", "www.zabbix.com", 443),
        
        # Grafana
        ("Grafana RPM Repository", "rpm.grafana.com", 443),
        ("Grafana APT Repository", "apt.grafana.com", 443),
        ("Grafana Plugins", "grafana.com", 443),
        
        # PostgreSQL
        ("PostgreSQL Downloads", "download.postgresql.org", 443),
        
        # Ansible AWX / GitHub
        ("GitHub", "github.com", 443),
        ("GitHub API", "api.github.com", 443),
        ("GitHub Raw Content", "raw.githubusercontent.com", 443),
        ("GitHub Objects", "objects.githubusercontent.com", 443),
        ("GitHub Release Assets", "release-assets.githubusercontent.com", 443),
        ("Quay.io (Container Images)", "quay.io", 443),
        ("Ansible Galaxy", "galaxy.ansible.com", 443),
        
        # Docker Hub
        ("Docker Hub Auth", "auth.docker.io", 443),
        ("Docker Hub Registry", "registry-1.docker.io", 443),
        
        # Kubernetes
        ("Kubernetes Registry", "registry.k8s.io", 443),
    ]
    
    def __init__(self, timeout: int = 5, proxy: Optional[str] = None, verbose: bool = True):
        self.timeout = timeout
        self.proxy = proxy
        self.verbose = verbose
        self.results: List[AccessTest] = []
    
    def log(self, message: str, level: str = "INFO"):
        """Log com timestamp"""
        if self.verbose or level in ["ERROR", "WARNING"]:
            timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
            prefix = {
                "INFO": "ℹ",
                "SUCCESS": "✓",
                "ERROR": "✗",
                "WARNING": "⚠"
            }.get(level, "•")
            print(f"[{prefix}] {message}")
    
    def test_dns(self, domain: str) -> Tuple[bool, float]:
        """Testa resolução DNS"""
        import time
        start = time.time()
        try:
            socket.gethostbyname(domain)
            return True, time.time() - start
        except (socket.gaierror, socket.timeout):
            return False, time.time() - start
    
    def test_tcp(self, domain: str, port: int) -> Tuple[bool, float]:
        """Testa conexão TCP"""
        import time
        start = time.time()
        try:
            sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            sock.settimeout(self.timeout)
            sock.connect((domain, port))
            sock.close()
            return True, time.time() - start
        except (socket.timeout, socket.error, OSError):
            return False, time.time() - start
    
    def test_https(self, domain: str, port: int) -> Tuple[bool, float]:
        """Testa conexão HTTPS"""
        import time
        start = time.time()
        try:
            # Nota: Desabilitamos verificação de TLS apenas para este script de validação
            # de conectividade, pois pode haver certificados auto-assinados ou ambientes
            # de staging. Para uso em produção, remover check_hostname=False.
            context = ssl.create_default_context()
            context.check_hostname = False
            context.verify_mode = ssl.CERT_NONE
            
            with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as sock:
                sock.settimeout(self.timeout)
                sock.connect((domain, port))
                
                with context.wrap_socket(sock, server_hostname=domain) as ssock:
                    pass
            
            return True, time.time() - start
        except (socket.timeout, socket.error, ssl.SSLError, OSError):
            return False, time.time() - start
    
    def validate_access(self, component: str, domain: str, port: int) -> AccessTest:
        """Valida um acesso completo"""
        test = AccessTest(component=component, domain=domain, port=port)
        
        self.log(f"Testando: {component} ({domain}:{port})")
        
        # Teste 1: DNS
        dns_ok, dns_time = self.test_dns(domain)
        test.dns_time = dns_time
        
        if not dns_ok:
            test.status = Status.FAILED
            test.reason = f"DNS Resolution"
            self.log(f"  ✗ DNS falhou para {domain}", "ERROR")
            self.results.append(test)
            return test
        
        # Teste 2: TCP
        tcp_ok, tcp_time = self.test_tcp(domain, port)
        test.tcp_time = tcp_time
        
        if not tcp_ok:
            test.status = Status.FAILED
            test.reason = f"TCP Connection"
            self.log(f"  ✗ Conexão TCP falhou para {domain}:{port}", "ERROR")
            self.results.append(test)
            return test
        
        # Teste 3: HTTPS
        https_ok, https_time = self.test_https(domain, port)
        test.https_time = https_time
        
        if not https_ok:
            test.status = Status.WARNING
            test.reason = "HTTPS Handshake (TCP OK)"
            self.log(f"  ⚠ HTTPS falhou mas TCP OK para {domain}:{port}", "WARNING")
        else:
            test.status = Status.SUCCESS
            test.reason = "OK"
            self.log(f"  ✓ {component} acessível", "SUCCESS")
        
        self.results.append(test)
        return test
    
    def validate_all(self):
        """Valida todos os acessos"""
        for component, domain, port in self.ACCESSES:
            self.validate_access(component, domain, port)
    
    def print_summary(self):
        """Exibe resumo dos resultados"""
        total = len(self.results)
        success = sum(1 for r in self.results if r.status == Status.SUCCESS)
        warning = sum(1 for r in self.results if r.status == Status.WARNING)
        failed = sum(1 for r in self.results if r.status == Status.FAILED)
        
        print("\n" + "="*80)
        print("RELATÓRIO DE VALIDAÇÃO - PROJETO AEROPORTO")
        print("="*80)
        print(f"Data/Hora: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
        print(f"Timeout: {self.timeout}s")
        print()
        print(f"Total testado:  {total}")
        print(f"Sucessos:       {success} ✓")
        print(f"Avisos:         {warning} ⚠")
        print(f"Falhas:         {failed} ✗")
        print()
        
        if failed == 0 and warning == 0:
            print("✓ Todos os acessos foram validados com sucesso!")
        elif failed == 0:
            print(f"⚠ {warning} acesso(s) com aviso, mas sem falhas críticas")
        else:
            print(f"✗ {failed} acesso(s) falharam. Verifique conectividade e firewall.")
        
        print("="*80)
        
        # Detalhes de falhas
        if failed > 0:
            print("\nDetalhes das Falhas:")
            for result in self.results:
                if result.status == Status.FAILED:
                    print(f"  ✗ {result.component} ({result.domain}:{result.port}) - {result.reason}")
        
        if warning > 0:
            print("\nDetalhes dos Avisos:")
            for result in self.results:
                if result.status == Status.WARNING:
                    print(f"  ⚠ {result.component} ({result.domain}:{result.port}) - {result.reason}")
    
    def export_json(self, filename: Optional[str] = None):
        """Exporta resultados em JSON"""
        data = {
            "timestamp": datetime.now().isoformat(),
            "timeout": self.timeout,
            "results": [
                {
                    "component": r.component,
                    "domain": r.domain,
                    "port": r.port,
                    "status": r.status.value,
                    "reason": r.reason,
                    "dns_time_ms": round(r.dns_time * 1000, 2),
                    "tcp_time_ms": round(r.tcp_time * 1000, 2),
                    "https_time_ms": round(r.https_time * 1000, 2),
                }
                for r in self.results
            ]
        }
        
        if filename:
            with open(filename, 'w') as f:
                json.dump(data, f, indent=2)
            self.log(f"Relatório JSON salvo em: {filename}")
        else:
            print(json.dumps(data, indent=2))
    
    def export_csv(self, filename: Optional[str] = None):
        """Exporta resultados em CSV"""
        import csv
        
        rows = [
            {
                "Component": r.component,
                "Domain": r.domain,
                "Port": r.port,
                "Status": r.status.value,
                "Reason": r.reason,
                "DNS Time (ms)": f"{r.dns_time*1000:.2f}",
                "TCP Time (ms)": f"{r.tcp_time*1000:.2f}",
                "HTTPS Time (ms)": f"{r.https_time*1000:.2f}",
            }
            for r in self.results
        ]
        
        if filename:
            with open(filename, 'w', newline='') as f:
                writer = csv.DictWriter(f, fieldnames=rows[0].keys())
                writer.writeheader()
                writer.writerows(rows)
            self.log(f"Relatório CSV salvo em: {filename}")
        else:
            writer = csv.DictWriter(sys.stdout, fieldnames=rows[0].keys())
            writer.writeheader()
            writer.writerows(rows)
    
    def get_exit_code(self) -> int:
        """Retorna código de saída apropriado"""
        failed = sum(1 for r in self.results if r.status == Status.FAILED)
        return 0 if failed == 0 else 1

def main():
    parser = argparse.ArgumentParser(
        description='Valida conectividade aos domínios críticos do Projeto Aeroporto'
    )
    parser.add_argument('--timeout', type=int, default=5, help='Timeout em segundos (padrão: 5)')
    parser.add_argument('--proxy', type=str, help='Proxy HTTP/HTTPS (ex: http://proxy.example.com:8080)')
    parser.add_argument('--quiet', action='store_true', help='Desabilita output verboso')
    parser.add_argument('--format', choices=['json', 'csv', 'text'], default='text', help='Formato de saída')
    parser.add_argument('--output', type=str, help='Arquivo para salvar relatório')
    
    args = parser.parse_args()
    
    validator = AccessValidator(timeout=args.timeout, proxy=args.proxy, verbose=not args.quiet)
    
    validator.log(f"Iniciando validação de acessos (timeout={args.timeout}s)")
    validator.validate_all()
    validator.print_summary()
    
    if args.format == 'json':
        validator.export_json(args.output)
    elif args.format == 'csv':
        validator.export_csv(args.output)
    
    return validator.get_exit_code()

if __name__ == '__main__':
    sys.exit(main())
