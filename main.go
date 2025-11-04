package main

import (
	"context"
	"flag"
	"fmt"
	"io"
	"log"
	"os"
	"strings"
	"time"

	corev1 "k8s.io/api/core/v1"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/fields"
	"k8s.io/client-go/kubernetes"
	"k8s.io/client-go/rest"
	"k8s.io/client-go/tools/clientcmd"
)

func getKubeconfig(kubeconfig string) (*rest.Config, error) {
	if kubeconfig != "" {
		return clientcmd.BuildConfigFromFlags("", kubeconfig)
	}
	if cfg, err := rest.InClusterConfig(); err == nil {
		return cfg, nil
	}
	return nil, fmt.Errorf("no kubeconfig found")
}

func getCurrentNamespace() string {
	if b, err := os.ReadFile("/var/run/secrets/kubernetes.io/serviceaccount/namespace"); err == nil {
		if ns := strings.TrimSpace(string(b)); ns != "" {
			return ns
		}
	}
	return ""
}

func streamLogs(ctx context.Context, c *kubernetes.Clientset, ns, name string) {
	req := c.CoreV1().Pods(ns).GetLogs(name, &corev1.PodLogOptions{Follow: true, Container: "hello"})
	stream, err := req.Stream(ctx)
	if err != nil {
		log.Printf("failed to start log stream: %v", err)
		return
	}
	defer stream.Close()
	io.Copy(os.Stdout, stream)
}

func watchPod(ctx context.Context, c *kubernetes.Clientset, ns, name string) error {
	w, err := c.CoreV1().Pods(ns).Watch(ctx, metav1.ListOptions{
		FieldSelector: fields.OneTermEqualSelector("metadata.name", name).String(),
	})
	if err != nil {
		return fmt.Errorf("failed to watch pod: %w", err)
	}
	defer w.Stop()

	log.Printf("watching pod %s/%s ...", ns, name)

	for {
		select {
		case <-ctx.Done():
			return ctx.Err()
		case ev, ok := <-w.ResultChan():
			if !ok {
				return fmt.Errorf("watch closed")
			}
			pod, ok := ev.Object.(*corev1.Pod)
			if !ok {
				continue
			}

			log.Printf("phase: %s", pod.Status.Phase)

			for _, cs := range pod.Status.ContainerStatuses {
				if cs.State.Running != nil {
					go streamLogs(ctx, c, ns, name)
				}
			}

			if pod.Status.Phase == corev1.PodSucceeded || pod.Status.Phase == corev1.PodFailed {
				return nil
			}
		}
	}
}

func main() {
	var (
		nsFlag     = flag.String("ns", "actions-runner-system", "namespace")
		name       = flag.String("name", "hello", "pod name")
		image      = flag.String("image", "busybox:1.35.0", "image")
		timeout    = flag.Duration("timeout", 120*time.Second, "timeout")
		kubeconfig = flag.String("kubeconfig", "", "kubeconfig path")
	)
	flag.Parse()

	jwt := os.Getenv("JWT")
	if jwt == "" {
		log.Fatal("missing GitHub JWT (env: JWT)")
	}

	cfg, err := getKubeconfig(*kubeconfig)
	if err != nil {
		log.Fatalf("config: %v", err)
	}
	cfg.BearerToken = jwt

	client, err := kubernetes.NewForConfig(cfg)
	if err != nil {
		log.Fatalf("client: %v", err)
	}

	ns := getCurrentNamespace()
	if ns == "" {
		ns = *nsFlag
	}

	ctx, cancel := context.WithTimeout(context.Background(), *timeout)
	defer cancel()

	pod := &corev1.Pod{
		ObjectMeta: metav1.ObjectMeta{Name: *name, Namespace: ns},
		Spec: corev1.PodSpec{
			RestartPolicy: corev1.RestartPolicyNever,
			Containers: []corev1.Container{{
				Name:    "hello",
				Image:   *image,
				Command: []string{"sh", "-c", "echo Hello world; sleep 1"},
			}},
		},
	}
	if _, err := client.CoreV1().Pods(ns).Create(ctx, pod, metav1.CreateOptions{}); err != nil {
		log.Fatalf("failed to create pod: %v", err)
	}

	if err := watchPod(ctx, client, ns, *name); err != nil {
		log.Fatalf("failed to watch pod: %v", err)
	}

	if p, err := client.CoreV1().Pods(ns).Get(ctx, *name, metav1.GetOptions{}); err == nil {
		log.Printf("final phase: %s", p.Status.Phase)
	}

	if err := client.CoreV1().Pods(ns).Delete(ctx, *name, metav1.DeleteOptions{}); err != nil {
		log.Fatalf("failed to delete pod: %v", err)
	}
}
