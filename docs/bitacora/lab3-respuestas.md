
# Preguntas de comprobación

## 8.1.1. Docker

### 1. ¿Qué diferencia hay entre una imagen y un contenedor? Usa como ejemplo lo que hiciste en los ejercicios G2 y G4.

Una **imagen** es una plantilla inmutable a partir de la cual Docker puede crear contenedores. Contiene el sistema de archivos y los elementos necesarios para ejecutar una aplicación. Un **contenedor**, en cambio, es una instancia creada a partir de esa imagen que se ejecuta de forma aislada.

En el ejercicio G2, `hello-world` fue la imagen utilizada para crear un contenedor que ejecutó su proceso y terminó. En G4 se utilizó un contenedor interactivo para entrar en él y comprobar que era posible ejecutar comandos dentro de esa instancia. Por tanto, una misma imagen puede utilizarse como base para crear múltiples contenedores independientes.

### 2. En el Ejercicio G5 el archivo `nota.txt` desapareció y en el G6 no. Explica por qué.

La diferencia está en dónde se almacenó el archivo. En G5, `nota.txt` se creó directamente dentro del sistema de archivos temporal del contenedor. Al eliminar ese contenedor con `docker rm`, también desapareció todo lo que se había almacenado únicamente en él.

En G6, el archivo se creó dentro de un **volumen con nombre**, montado en el contenedor. El volumen tiene un ciclo de vida independiente del contenedor, por lo que los datos permanecieron disponibles incluso después de eliminar el contenedor. Esta es precisamente la razón por la que Oracle utiliza el volumen `oralab-26ai-data` para conservar sus archivos de datos.

### 3. ¿Qué diferencia hay entre `docker ps` y `docker ps -a`, y qué significa `STATUS = Exited (0)`?

`docker ps` muestra únicamente los contenedores que están actualmente en ejecución, mientras que `docker ps -a` muestra todos los contenedores, incluidos los que ya terminaron.

El estado `Exited (0)` indica que el proceso principal del contenedor terminó y devolvió el código de salida `0`, que convencionalmente significa que finalizó correctamente.

### 4. En `-p 8181:8181`, ¿qué número corresponde a tu equipo y cuál al contenedor? ¿Qué pasaría con `-p 80:8080` en el ejercicio de nginx?

El formato de `-p` es **puerto del equipo anfitrión : puerto del contenedor**. Por tanto, en `-p 8181:8181`, el primer `8181` corresponde al puerto de mi equipo y el segundo al puerto que escucha dentro del contenedor.

En el ejercicio de nginx, el mapeo utilizado fue `-p 8080:80`: las peticiones realizadas al puerto `8080` del equipo se redirigen al puerto `80` del contenedor, donde escucha nginx. Si se utilizara `-p 80:8080`, se invertiría el sentido del mapeo: el equipo expondría el puerto `80` y Docker enviaría las peticiones al puerto `8080` del contenedor. Si nginx siguiera escuchando en el puerto `80`, esa configuración no funcionaría porque no coincidiría con el puerto donde está escuchando el servicio.

### 5. ¿Por qué un contenedor de Oracle se queda en marcha y el de `hello-world` termina solo?

La diferencia no depende de que uno sea Oracle y otro Docker, sino del **proceso principal que ejecuta cada contenedor**. `hello-world` ejecuta un proceso muy corto: imprime su mensaje y termina; cuando termina el proceso principal, el contenedor también finaliza.

Oracle, en cambio, necesita mantener en ejecución procesos de base de datos y servicios asociados para poder aceptar conexiones y atender consultas. Por eso el contenedor permanece en estado `Up` mientras Oracle está funcionando.

### 6. ¿Qué es el digest de una imagen y por qué lo registramos si ya sabemos que usamos `:latest`?

El **digest** es una huella criptográfica, normalmente identificada mediante `sha256`, que permite identificar exactamente una versión concreta de una imagen.

La etiqueta `:latest` no representa una versión inmutable: puede apuntar a una imagen diferente cuando el registro publique una actualización. Por eso registramos el digest obtenido durante la instalación. De esta manera podemos saber exactamente qué versión de la imagen se utilizó y reproducir el entorno posteriormente, aunque `latest` haya cambiado.

### 7. ¿Qué comando borraría realmente los datos de Oracle? ¿Por qué `docker rm oralab-26ai` no lo hace?

El comando que eliminaría los datos almacenados en el volumen sería:

```bash
docker volume rm oralab-26ai-data
```

`docker rm oralab-26ai` únicamente elimina el contenedor. Los datos de Oracle están almacenados en el volumen con nombre `oralab-26ai-data`, cuyo ciclo de vida es independiente del contenedor. Esta separación permite eliminar y recrear el contenedor sin perder los datos de la base de datos.

Por eso eliminar el volumen es una operación destructiva que debe realizarse únicamente cuando realmente se quiera eliminar esos datos.

---

## 8.1.2. Git, organización y evidencia

### 8. ¿Por qué este laboratorio se hace dentro del repositorio `oracle-database-lab`, con Issue, branch y Pull Request, en vez de en una carpeta aparte?

El objetivo es tratar la instalación del entorno como un cambio de infraestructura **reproducible, verificable y revisable**, y no como una configuración manual que solo funciona en mi equipo.

Al mantener los scripts, migraciones y evidencias dentro del repositorio, otra persona puede revisar qué se ejecutó, reproducir el proceso y comprobar sus resultados. Además, el flujo Issue → branch → commits → Pull Request → review → merge proporciona trazabilidad sobre los cambios realizados.

Esto también evita crear un entorno irrepetible o *snowflake environment*, cuyo conocimiento dependa únicamente de la persona que lo configuró.

### 9. ¿Qué diferencia hay entre `source 00-config.sh` y `bash 00-config.sh`? ¿Por qué usamos `source`?

`bash 00-config.sh` ejecuta el archivo en una nueva instancia de Bash. Cuando esa instancia termina, las variables y funciones definidas allí no quedan disponibles en la terminal desde la que se lanzó.

`source 00-config.sh`, en cambio, ejecuta el contenido dentro de la shell actual. Por eso las variables como `CONT_NAME`, `SERVICE_PDB` o `EVID`, y la función `ts`, permanecen disponibles para los siguientes comandos.

Utilizamos `source` porque `00-config.sh` funciona como archivo de configuración del entorno que debe cargar sus variables en la terminal de trabajo.

### 10. Explica cada parte del nombre `20260915T091230Z_02-docker.script.log`.

El nombre sigue una convención diseñada para que la evidencia sea identificable y ordenable cronológicamente:

- `20260915` representa la fecha: 15 de septiembre de 2026.
- `T` separa la fecha de la hora siguiendo el formato ISO 8601.
- `091230` representa la hora `09:12:30`.
- `Z` indica que la hora está expresada en UTC.
- `_02` identifica el número del paso que produjo la evidencia.
- `docker` describe brevemente el contenido.
- `.script.log` indica que se trata de una grabación de la salida de una sesión o script de terminal.

La convención permite relacionar rápidamente una evidencia con el paso que la produjo y ordenar los archivos independientemente de la zona horaria del equipo.

### 11. ¿Para qué sirve `.gitattributes` y qué error evita?

`.gitattributes` permite establecer reglas sobre cómo Git debe tratar determinados tipos de archivos. En este laboratorio se utiliza, entre otras cosas, para establecer finales de línea `LF` en archivos `.sh`, `.sql` y `.md`.

Esto es importante porque Windows utiliza normalmente `CRLF`, mientras que Linux utiliza `LF`. Si un script Bash creado o modificado desde Windows termina almacenándose con `CRLF`, puede producir errores como `$'\r': command not found` al ejecutarse en Linux.

Por tanto, `.gitattributes` evita diferencias innecesarias en los *diffs* y, sobre todo, problemas de ejecución al compartir scripts entre Windows y Linux.

### 12. ¿Por qué en este Pull Request elegimos `Create a merge commit` en lugar de `Squash and merge`?

Elegimos `Create a merge commit` porque queremos conservar en el historial los commits individuales que documentan las diferentes etapas del laboratorio. Cada commit representa un cambio concreto y permite mantener la trazabilidad del proceso de instalación y documentación.

Con `Squash and merge`, todos esos commits se convertirían en uno solo al integrarse en `main`. Aunque el resultado funcional podría ser el mismo, perderíamos parte del historial detallado que resulta útil para revisar cómo se construyó el entorno.

---

## 8.1.3. Seguridad

### 13. Describe las cuatro capas de la estrategia de contraseñas (Parte D) y qué pasaría si te saltas la primera.

La estrategia está diseñada para impedir que una contraseña termine accidentalmente en Git y consta de cuatro capas complementarias.

Primero, **Git debe saber qué archivo ignorar**, por lo que `config/.env` se añade a `.gitignore` antes de crear el archivo real. Segundo, se mantiene una **plantilla versionada**, `config/.env.example`, que contiene únicamente nombres de variables y valores de ejemplo, nunca secretos reales. Tercero, la configuración real se almacena localmente en `config/.env`, que no debe formar parte del repositorio. Finalmente, la contraseña se introduce de forma segura mediante el mecanismo indicado por el laboratorio, evitando escribirla directamente en scripts o comandos versionables.

Si se omite la primera capa y Git no está configurado para ignorar `config/.env`, existe el riesgo de que el archivo con las credenciales se incluya accidentalmente en un `git add` y termine publicado en el repositorio.

### 14. ¿Por qué no escribimos la contraseña directamente en el comando `docker run`, aunque el script no se suba a Git?

Porque una contraseña escrita directamente en un comando puede quedar registrada en el **historial de la shell**, en evidencias de terminal o en otros mecanismos de auditoría. Que el script no se suba a Git no elimina esos otros riesgos.

La práctica correcta es separar la configuración sensible del código y hacer que el script lea las credenciales desde `config/.env`, que está excluido del control de versiones.

### 15. Si descubres tu contraseña en un commit ya publicado, ¿basta con borrarla en un commit nuevo? ¿Qué debes hacer?

No. Crear un commit posterior que elimine la contraseña no elimina el secreto del historial anterior de Git. Una persona que tenga acceso al repositorio podría consultar los commits anteriores y recuperar la credencial.

La primera medida debe ser **considerar la contraseña comprometida y cambiarla o revocarla inmediatamente**. Después se debe eliminar el secreto del historial siguiendo el procedimiento correspondiente y revisar el repositorio para comprobar que no existan otras exposiciones.

La idea fundamental es que una credencial publicada debe tratarse como un incidente de seguridad, no simplemente como un error de edición.

---

## 8.1.4. Oracle y herramientas

### 16. ¿Por qué no usamos SPOOL ni `@archivo.sql` con SQL*Plus dentro del contenedor, y qué hicimos en su lugar?

La idea del laboratorio es mantener los scripts y las evidencias en el repositorio de Linux, en lugar de depender de archivos creados dentro del contenedor de Oracle.

Por eso los scripts SQL se mantienen fuera del contenedor y se pasan a `sqlplus` mediante la entrada estándar. De forma equivalente, la salida se captura desde la terminal con `tee` o mediante `SPOOL` cuando corresponde a una sesión de SQLcl. Así, los archivos fuente y las evidencias permanecen en el repositorio y no dependen del sistema de archivos temporal del contenedor.

Esto mantiene separadas las responsabilidades: el contenedor ejecuta Oracle, mientras que el repositorio conserva los scripts y el historial de lo realizado.

### 17. ¿Qué hace `WHENEVER SQLERROR EXIT SQL.SQLCODE` al inicio de V000 y V001, y qué pasaría sin esa línea?

La instrucción indica a SQL*Plus que, si se produce un error SQL, debe terminar la ejecución devolviendo el código de error correspondiente.

Esto es importante en una migración porque evita continuar ejecutando instrucciones sobre un estado que posiblemente ya sea incorrecto. Sin esta instrucción, un error podría pasar desapercibido y el script podría continuar con las siguientes sentencias, dejando una migración parcialmente aplicada y más difícil de diagnosticar.

### 18. ¿Qué es una migración y por qué V000 y V001 no se deben editar una vez aplicadas?

Una **migración** es un script versionado que aplica de manera controlada un cambio sobre la estructura o configuración de una base de datos. En este laboratorio, V000 y V001 representan pasos concretos y ordenados de aprovisionamiento.

Una vez aplicadas, no deben modificarse porque se perdería la correspondencia entre el historial versionado y lo que realmente se ejecutó en la base de datos. Si posteriormente fuera necesario realizar otro cambio, lo correcto sería crear una nueva migración. De esta forma se conserva la trazabilidad y es posible reconstruir qué cambios se aplicaron y en qué orden.

### 19. ¿Por qué en SQL Developer se usa el servicio `FREEPDB1` y no `FREE` ni un SID?

`FREEPDB1` es el servicio correspondiente a la **Pluggable Database (PDB)** en la que trabajamos durante el laboratorio. `FREE` corresponde al servicio de la base de datos contenedora (CDB), mientras que un SID identifica una instancia y no es la forma adecuada de seleccionar la PDB que queremos utilizar.

Por ello, al conectar las herramientas de trabajo utilizamos `FREEPDB1`: queremos establecer la sesión directamente en la PDB donde están los usuarios y objetos de trabajo del laboratorio.

### 20. ¿Qué aporta SQLcl frente a SQL*Plus, y por qué un DBA debe dominar ambas?

SQLcl proporciona una experiencia de línea de comandos más moderna y cómoda para trabajar con Oracle, con funcionalidades adicionales de edición, formato y gestión de conexiones. Resulta especialmente útil para el trabajo interactivo y para determinadas tareas de automatización.

SQL*Plus, por otro lado, sigue siendo una herramienta fundamental del ecosistema Oracle y aparece ampliamente en scripts, procedimientos de administración y entornos donde se busca una interfaz mínima y ampliamente disponible.

Un DBA debe conocer ambas porque no siempre podrá elegir la herramienta disponible. Dominar SQL*Plus garantiza compatibilidad con scripts y entornos tradicionales, mientras que SQLcl ofrece una experiencia más moderna para el trabajo diario.

---

## 8.1.5. Entorno de trabajo

### 21. ¿Por qué el curso pasa de Git Bash a Ubuntu en WSL 2? Da al menos dos problemas concretos de Git Bash que desaparecen en Ubuntu.

El cambio responde a que el laboratorio empieza a trabajar con herramientas propias de un entorno Linux real, que es el contexto habitual de servidores, contenedores, Oracle y sistemas de CI/CD. Ubuntu en WSL 2 permite trabajar con un kernel Linux y con las mismas rutas, permisos y herramientas que se encuentran en un servidor Linux.

Git Bash resulta suficiente para aprender Git, pero introduce una capa de emulación que puede provocar problemas concretos. Por ejemplo, puede convertir o interpretar rutas Linux como rutas de Windows, generar dificultades con argumentos de Docker y requerir herramientas como `winpty` para determinadas operaciones interactivas. Además, no proporciona de forma nativa muchas utilidades de administración utilizadas en el laboratorio, como `free`, `ss` o `htop`.

Con Ubuntu en WSL 2 se elimina esa capa de emulación y se trabaja directamente con el entorno Linux para el que están diseñadas estas herramientas.

### 22. ¿Por qué clonamos el repositorio en `~/oracle-database-lab` y no trabajamos sobre la carpeta de Windows (`/mnt/c/...`)? ¿Y por qué recomendamos bash frente a zsh para los scripts del curso?

El repositorio se clona en `~/oracle-database-lab` porque esa ubicación pertenece al sistema de archivos de Linux de WSL. Trabajar directamente sobre `/mnt/c/...` implica cruzar constantemente entre los sistemas de archivos de Windows y Linux, lo que puede provocar una menor velocidad, problemas de permisos y diferencias en los finales de línea. Además, los scripts de infraestructura pueden verse afectados por estas diferencias.

Respecto a las shells, `bash` es la opción recomendada para los scripts porque es la shell estándar disponible en prácticamente todos los servidores Linux, incluidos los entornos habituales de administración y CI/CD. `zsh` puede ser más cómoda para el trabajo interactivo, especialmente en macOS, pero presenta algunas diferencias respecto a Bash en aspectos como expansión de variables, *globbing* o arrays.

Por eso la recomendación profesional es mantener los **scripts compartidos en Bash**, garantizando así un comportamiento consistente en los distintos entornos donde puedan ejecutarse.