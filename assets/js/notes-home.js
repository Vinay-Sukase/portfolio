(function () {
  const subjects = Array.isArray(window.NOTES_SUBJECTS)
    ? window.NOTES_SUBJECTS
    : [];
  const params = new URLSearchParams(window.location.search);
  const subjectSlug = params.get("subject") || "";

  const elements = {
    subjectsView: document.getElementById("subjectsView"),
    readerView: document.getElementById("readerView"),
    subjectsGrid: document.getElementById("subjectsGrid"),
    subjectEyebrow: document.getElementById("subjectEyebrow"),
    subjectTitle: document.getElementById("subjectTitle"),
    subjectDescription: document.getElementById("subjectDescription"),
    topicNoteList: document.getElementById("topicNoteList"),
    readerTopic: document.getElementById("readerTopic"),
    readerTitle: document.getElementById("readerTitle"),
    readerMeta: document.getElementById("readerMeta"),
    readerBody: document.getElementById("readerBody"),
    readerSource: document.getElementById("readerSource"),
  };

  let activeFetchToken = 0;

  if (!elements.subjectsGrid) {
    return;
  }

  renderSubjectGrid();

  if (subjectSlug) {
    const selectedSubject = subjects.find(function (subject) {
      return subject.slug === subjectSlug;
    });

    if (selectedSubject) {
      openSubject(selectedSubject);
    }
  }

  function renderSubjectGrid() {
    elements.subjectsGrid.innerHTML = "";

    subjects.forEach(function (subject) {
      const card = document.createElement("a");
      const topicCount = Array.isArray(subject.topics)
        ? subject.topics.length
        : 0;
      card.className = "topic-card";
      card.href = "notes.html?subject=" + encodeURIComponent(subject.slug);
      card.innerHTML =
        '<div class="topic-card-top">' +
        '<p class="topic-card-label">Subject</p>' +
        '<span class="topic-card-count">' +
        topicCount +
        (topicCount === 1 ? " topic" : " topics") +
        "</span>" +
        "</div>" +
        "<h3>" +
        escapeHtml(subject.name) +
        "</h3>" +
        '<p class="topic-card-description">' +
        escapeHtml(subject.description || "Open subject notes.") +
        "</p>";

      elements.subjectsGrid.appendChild(card);
    });
  }

  function openSubject(subject) {
    const topics = Array.isArray(subject.topics) ? subject.topics : [];
    let activeTopic = topics[0] || null;

    elements.subjectsView.classList.add("is-hidden");
    elements.readerView.classList.remove("is-hidden");
    elements.subjectEyebrow.textContent = "Subject Notes";
    elements.subjectTitle.textContent = subject.name;
    elements.subjectDescription.textContent =
      subject.description || "Choose a note from the list to start reading.";

    if (!topics.length) {
      elements.topicNoteList.innerHTML =
        '<div class="empty-message">No topic folders were found for this subject yet.</div>';
      elements.readerTitle.textContent = "No notes yet";
      elements.readerMeta.textContent =
        "Add a topic folder with an exported HTML file and regenerate the notes data.";
      elements.readerBody.className = "reader-body empty-state";
      elements.readerBody.innerHTML =
        "<p>This subject is ready for future notes.</p>";
      return;
    }

    renderTopicList();
    renderTopic(activeTopic);

    function renderTopicList() {
      elements.topicNoteList.innerHTML = "";

      topics.forEach(function (topic) {
        const button = document.createElement("button");
        button.type = "button";
        button.className =
          "topic-note-button" +
          (activeTopic && topic.slug === activeTopic.slug ? " active" : "");
        button.innerHTML = "<strong>" + escapeHtml(topic.label) + "</strong>";

        button.addEventListener("click", function () {
          activeTopic = topic;
          renderTopicList();
          renderTopic(topic);
        });

        elements.topicNoteList.appendChild(button);
      });
    }
  }

  function renderTopic(topic) {
    elements.readerTopic.textContent = "Topic";
    elements.readerTitle.textContent = topic.label;
    elements.readerMeta.textContent = topic.source || "HTML note";
    elements.readerSource.classList.remove("disabled");
    elements.readerSource.removeAttribute("aria-disabled");
    elements.readerSource.href = topic.file;
    elements.readerSource.textContent = "Open Note File";

    const fetchToken = ++activeFetchToken;
    elements.readerBody.className = "reader-body";
    elements.readerBody.innerHTML = "<p>Loading note...</p>";

    fetch(topic.file)
      .then(function (response) {
        if (!response.ok) {
          throw new Error("Failed to load note");
        }
        return response.text();
      })
      .then(function (content) {
        if (fetchToken !== activeFetchToken) {
          return;
        }

        elements.readerBody.className = "reader-body";
        elements.readerBody.innerHTML = renderHtmlNote(content, topic.file);
      })
      .catch(function () {
        if (fetchToken !== activeFetchToken) {
          return;
        }

        elements.readerBody.className = "reader-body";
        elements.readerBody.innerHTML =
          '<div class="empty-message">' +
          "<p>The note preview could not be loaded automatically.</p>" +
          "<p>If you are opening the page directly as a local file, your browser may block loading the exported HTML note. The original note file is still available from the button above.</p>" +
          "</div>";
      });
  }

  function renderHtmlNote(html, filePath) {
    const parser = new DOMParser();
    const documentNode = parser.parseFromString(html, "text/html");
    const pageBody =
      documentNode.querySelector(".page-body") ||
      documentNode.querySelector("article") ||
      documentNode.body;
    const baseUrl = new URL(filePath, window.location.href);
    const container = document.createElement("div");

    container.className = "notion-import";
    container.innerHTML = pageBody
      ? pageBody.innerHTML
      : "<p>Unable to read the exported HTML note.</p>";

    container
      .querySelectorAll("table.properties, .page-description, .icon")
      .forEach(function (node) {
        node.remove();
      });

    container.querySelectorAll("[href]").forEach(function (node) {
      const href = node.getAttribute("href");
      if (!href) {
        return;
      }
      node.setAttribute("href", resolveUrl(href, baseUrl));
      node.setAttribute("target", "_blank");
      node.setAttribute("rel", "noreferrer");
    });

    container.querySelectorAll("[src]").forEach(function (node) {
      const src = node.getAttribute("src");
      if (!src) {
        return;
      }
      node.setAttribute("src", resolveUrl(src, baseUrl));
    });

    container.querySelectorAll("[style]").forEach(function (node) {
      node.removeAttribute("style");
    });

    return container.outerHTML;
  }

  function resolveUrl(url, baseUrl) {
    if (/^(https?:|mailto:|tel:|#|data:)/i.test(url)) {
      return url;
    }

    try {
      return new URL(url, baseUrl).href;
    } catch (error) {
      return url;
    }
  }

  function escapeHtml(value) {
    return String(value)
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;");
  }
})();
