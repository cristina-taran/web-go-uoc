package main

import (
	"html/template"
	"log"
	"net/http"
	"strings"
)

type pageData struct {
	Nombre string
}

func main() {
	page := template.Must(template.ParseFiles("templates/index.html"))

	http.Handle("/static/", http.StripPrefix("/static/", http.FileServer(http.Dir("static"))))
	http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/" {
			http.NotFound(w, r)
			return
		}
		if r.Method != http.MethodGet && r.Method != http.MethodPost {
			w.Header().Set("Allow", "GET, POST")
			http.Error(w, "Método no permitido", http.StatusMethodNotAllowed)
			return
		}

		data := pageData{}
		if r.Method == http.MethodPost {
			if err := r.ParseForm(); err != nil {
				http.Error(w, "Formulario no válido", http.StatusBadRequest)
				return
			}
			data.Nombre = strings.TrimSpace(r.FormValue("nombre"))
		}

		if err := page.Execute(w, data); err != nil {
			log.Printf("Error al mostrar la página: %v", err)
		}
	})

	log.Println("Servidor disponible en http://localhost:8080")
	log.Fatal(http.ListenAndServe(":8080", nil))
}
