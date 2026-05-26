final projectsJson = {
  "success": true,
  "message": "Projects retrieved successfully.",
  "data": [
    {
      "id": 3,
      "uuid": "00000003",
      "name": "Project 1",
      "code": "00000003",
      "status": "active",
      "client": {"id": 1, "company_name": "Ainex", "image": null},
      "customer": {
        "id": 1,
        "company_name": "AmbaniBkery",
        "client_id": 1,
        "image":
            "https://printhelper.s3.amazonaws.com/users/1774505189_69c4cce5c80d1.jpg",
      },
      "owner": {
        "id": 1,
        "name": "System Admin",
        "image":
            "https://printhelper.s3.amazonaws.com/users/thumb_1774853130_69ca1c0ab57c45.19960577.jpg",
      },
      "card_date_text": "04/09/26",
      "card_time_text": "4:15pm",
      "card_code": "00000003",
      "card_avatars": [
        {
          "key": "owner_1",
          "src":
              "https://printhelper.s3.amazonaws.com/users/thumb_1774853130_69ca1c0ab57c45.19960577.jpg",
          "alt": "System Admin",
          "title": "System Admin",
        },
        {
          "key": "client_1",
          "src":
              "https://production.printhelpers.com/icons/Print_Helpers_Icon.svg",
          "alt": "Ainex",
          "title": "Ainex",
        },
        {
          "key": "customer_1",
          "src":
              "https://printhelper.s3.amazonaws.com/users/1774505189_69c4cce5c80d1.jpg",
          "alt": "AmbaniBkery",
          "title": "AmbaniBkery",
        },
      ],
      "card_progress_percent": 0,
      "card_late_tasks_count": 1,
      "card_tasks_count": 2,
      "card_comments_count": 0,
      "card_attachments_count": 0,
      "card_progress_state": "todo",
    },
    {
      "id": 2,
      "uuid": "00000002",
      "name": "work flow check",
      "code": "00000002",
      "status": "active",
      "client": {"id": 1, "company_name": "Ainex", "image": null},
      "customer": {
        "id": 1,
        "company_name": "AmbaniBkery",
        "client_id": 1,
        "image":
            "https://printhelper.s3.amazonaws.com/users/1774505189_69c4cce5c80d1.jpg",
      },
      "owner": {
        "id": 1,
        "name": "System Admin",
        "image":
            "https://printhelper.s3.amazonaws.com/users/thumb_1774853130_69ca1c0ab57c45.19960577.jpg",
      },
      "card_date_text": "04/09/26",
      "card_time_text": "3:37pm",
      "card_code": "00000002",
      "card_avatars": [
        {
          "key": "owner_1",
          "src":
              "https://printhelper.s3.amazonaws.com/users/thumb_1774853130_69ca1c0ab57c45.19960577.jpg",
          "alt": "System Admin",
          "title": "System Admin",
        },
        {
          "key": "client_1",
          "src":
              "https://production.printhelpers.com/icons/Print_Helpers_Icon.svg",
          "alt": "Ainex",
          "title": "Ainex",
        },
        {
          "key": "customer_1",
          "src":
              "https://printhelper.s3.amazonaws.com/users/1774505189_69c4cce5c80d1.jpg",
          "alt": "AmbaniBkery",
          "title": "AmbaniBkery",
        },
      ],
      "card_progress_percent": 35,
      "card_late_tasks_count": 2,
      "card_tasks_count": 4,
      "card_comments_count": 1,
      "card_attachments_count": 1,
      "card_progress_state": "in_progress",
    },
    {
      "id": 1,
      "uuid": "00000001",
      "name": "work flow check",
      "code": "00000001",
      "status": "active",
      "client": {"id": 1, "company_name": "Ainex", "image": null},
      "customer": {
        "id": 1,
        "company_name": "AmbaniBkery",
        "client_id": 1,
        "image":
            "https://printhelper.s3.amazonaws.com/users/1774505189_69c4cce5c80d1.jpg",
      },
      "owner": {
        "id": 1,
        "name": "System Admin",
        "image":
            "https://printhelper.s3.amazonaws.com/users/thumb_1774853130_69ca1c0ab57c45.19960577.jpg",
      },
      "card_date_text": "04/09/26",
      "card_time_text": "3:33pm",
      "card_code": "00000001",
      "card_avatars": [
        {
          "key": "owner_1",
          "src":
              "https://printhelper.s3.amazonaws.com/users/thumb_1774853130_69ca1c0ab57c45.19960577.jpg",
          "alt": "System Admin",
          "title": "System Admin",
        },
        {
          "key": "client_1",
          "src":
              "https://production.printhelpers.com/icons/Print_Helpers_Icon.svg",
          "alt": "Ainex",
          "title": "Ainex",
        },
        {
          "key": "customer_1",
          "src":
              "https://printhelper.s3.amazonaws.com/users/1774505189_69c4cce5c80d1.jpg",
          "alt": "AmbaniBkery",
          "title": "AmbaniBkery",
        },
      ],
      "card_progress_percent": 100,
      "card_late_tasks_count": 0,
      "card_tasks_count": 2,
      "card_comments_count": 1,
      "card_attachments_count": 1,
      "card_progress_state": "done",
    },
  ],
  "meta": {
    "current_page": 1,
    "last_page": 1,
    "per_page": 16,
    "total": 3,
    "from": 1,
    "to": 3,
  },
  "links": {
    "first": "https://staging.printhelpers.com/api/projects?page=1",
    "last": "https://staging.printhelpers.com/api/projects?page=1",
    "prev": null,
    "next": null,
  },
};

final filesJson = {
  "status": true,
  "message": "success",
  "folders": [
    {"id": "122", "title": "Projects", "icon": "folder"},
    {"id": "222", "title": "My Files", "icon": "folder"},
    {"id": "333", "title": "Other", "icon": "folder"},
  ],
  "files": [
    {
      "id": "file1",
      "thumbnail":
          "https://images.pexels.com/photos/1557652/pexels-photo-1557652.jpeg",
      "filename": "filenamegoeshere.jpg",
      "uploadedBy": [
        "https://idsb.tmgrup.com.tr/ly/uploads/images/2023/11/14/301015.jpg",
      ],
      "type": "image",
    },
    {
      "id": "file2",
      "thumbnail":
          "https://cdn.pixabay.com/photo/2025/11/05/15/55/rose-9939147_640.jpg",
      "filename": "filenamegoeshere.jpg",
      "uploadedBy": [
        "https://i.pinimg.com/474x/60/5b/9b/605b9b86a82dd0147ed8aa612381326f.jpg",
      ],
      "type": "image",
    },
    {
      "id": "file3",
      "thumbnail":
          "https://images.pexels.com/photos/31284696/pexels-photo-31284696/free-photo-of-vibrant-sunflower-in-a-thai-field-captured-in-daylight.jpeg",
      "filename": "filenamegoeshere.jpg",
      "uploadedBy": [
        "https://idsb.tmgrup.com.tr/ly/uploads/images/2023/11/14/301015.jpg",
      ],
      "type": "image",
    },
    {
      "id": "file4",
      "thumbnail":
          "https://www.webyurt.com/images-o/images/photography-mountains.jpg",
      "filename": "filenamegoeshere.psd",
      "uploadedBy": [
        "https://i.pinimg.com/474x/60/5b/9b/605b9b86a82dd0147ed8aa612381326f.jpg",
      ],
      "type": "psd",
    },
  ],
};

final clientsData = {
  "status": true,
  "message": "success",
  "clients": [
    {
      "id": 1,
      "company_name": "Company Name",
      "company_type": "Design Studio",
      "created_date": "01/24/21",
      "created_time": "12:20pm",
      "projects": 4,
      "files": 3,
      "logo":
          "https://img.freepik.com/premium-vector/creative-elegant-abstract-minimalistic-logo-design-vector-any-brand-company_1253202-137644.jpg",
      "status": true,
      "contacts": [
        {
          "contact_id": 101,
          "name": "Name Lastname",
          "avatar":
              "https://img.freepik.com/premium-photo/happy-man-ai-generated-portrait-user-profile_1119669-1.jpg",
          "phones": ["(323) 808-4080", "(323) 808-4080"],
          "emails": ["email@printhlpers.com", "email@printhlpers.com"],
          "languages": ["English", "Español"],
          "status": false,
        },
        {
          "contact_id": 102,
          "name": "Name Lastname",
          "avatar":
              "https://idsb.tmgrup.com.tr/ly/uploads/images/2023/11/14/301015.jpg",
          "phones": ["(323) 808-2222", "(323) 808-3333"],
          "emails": ["email1@printhlpers.com", "email2@printhlpers.com"],
          "languages": ["English", "Español"],
          "status": false,
        },
      ],
    },
    {
      "id": 3,
      "company_name": "Company Name",
      "company_type": "Company Studio",
      "created_date": "01/24/21",
      "created_time": "12:20pm",
      "projects": 4,
      "files": 3,
      "logo":
          "https://img.freepik.com/premium-vector/creative-elegant-abstract-minimalistic-logo-design-vector-any-brand-company_1253202-137644.jpg",
      "status": false,
      "contacts": [
        {
          "contact_id": 121,
          "name": "Name Lastname",
          "avatar":
              "https://img.freepik.com/premium-photo/happy-man-ai-generated-portrait-user-profile_1119669-1.jpg",
          "phones": ["(323) 808-4080", "(323) 808-4080"],
          "emails": ["email@printhlpers.com", "email@printhlpers.com"],
          "languages": ["English", "Español"],
          "status": false,
        },
        {
          "contact_id": 122,
          "name": "Name Lastname",
          "avatar":
              "https://idsb.tmgrup.com.tr/ly/uploads/images/2023/11/14/301015.jpg",
          "phones": ["(323) 808-2222", "(323) 808-3333"],
          "emails": ["email1@printhlpers.com", "email2@printhlpers.com"],
          "languages": ["English", "Español"],
          "status": false,
        },
      ],
    },
  ],
};

final loginCredentials = {
  "status": true,
  "message": "success",
  "roles": {
    "ADMIN": {"username": "admin123", "password": "Admin@2024"},
    "CLIENT": {"username": "client123", "password": "Client@2024"},
    "STAFF": {"username": "staff123", "password": "Staff@2024"},
    "CUSTOMER": {"username": "customer123", "password": "Customer@2024"},
  },
};
